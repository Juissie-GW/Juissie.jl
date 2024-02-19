# Backend.jl

module Backend

using SQLite
using HNSW
using UUIDs
using DataFrames

include("Embedding.jl")
using .Embedding
include("TextUtils.jl")
using .TextUtils


export Corpus, upsert_chunk, upsert_document, search

"""
    struct Corpus

Basically a vector database. It will have these attributes:
1. a relational database (SQLite)
2. a vector index (HNSW)
3. an embedder (via Embedding.jl)

Attributes
----------
db : a SQLite.DB connection object
    this is a real relational database to store metadata (e.g. chunk text, doc name)
hnsw : Hierarchical Navigable Small World object
    this is our searchable vector index
embedder : Embedder
    an initialized Embedder struct
max_seq_len : int
    The maximum number of tokens per chunk.
    This should be the max sequence length of the tokenizer
data : Vector{Any}
    The embeddings get stored here before we create the vector index
next_idx : int
    stores the index we'll use for the next-upserted chunk

Notes
-----
The struct is mutable because we want to be able to change things like
incrementing next_idx.
"""
mutable struct Corpus
    db :: SQLite.DB
    hnsw :: Union{HNSW.HierarchicalNSW, Nothing}
    embedder :: Embedding.Embedder
    max_seq_len :: Int64
    data :: Vector{Any}
    next_idx :: Int64
end

"""
    function Corpus(corpus_name::String, embedder_model_path::String="BAAI/bge-small-en-v1.5")

Initializes a Corpus struct.

In particular, does the following:
1. Initializes an embedder object
2. Creates a SQLite databse with the corpus name. It should have:
- row-wise primary key uuid
- doc_name representing the *parent* document
- chunk text 
We can add more metadata later, if desired

Parameters
----------
corpus_name : str or nothing
    the name that you want to give the database
    optional. if left as nothing, we use an in-memory database
embedder_model_path : str
    a path to a HuggingFace-hosted model
    e.g. "BAAI/bge-small-en-v1.5"
max_seq_len : int
    The maximum number of tokens per chunk.
    This should be the max sequence length of the tokenizer
"""
function Corpus(corpus_name::Union{String, Nothing}=nothing, embedder_model_path::String="BAAI/bge-small-en-v1.5", max_seq_len::Int=512)
    # initialize embedder
    embedder = Embedder(embedder_model_path)

    # initialize database
    if isnothing(corpus_name)
        db = SQLite.DB() # in-memory db
    else
        db = SQLite.DB("$(corpus_name).db")
    end

    DBInterface.execute(db, "DROP TABLE IF EXISTS metadata")
    DBInterface.execute(db, """
    CREATE TABLE metadata (
        idx INT PRIMARY KEY,
        doc_name TEXT,
        chunk TEXT
    )
    """)

    # don't initialize hnsw yet because it needs initial features
    hnsw = nothing
    return Corpus(db, hnsw, embedder, max_seq_len, [], 1)
end

"""
    function generate_uuid()

Generates a random UUID each call. May be OBE now, actually.
"""
function generate_uuid()
    return string(UUIDs.uuid4()) # uuid4 should be completely random
end


"""
    function upsert_chunk(corpus::Corpus, chunk::String, doc_name::String)

Given a new chunk of text, get embedding and insert into our vector DB.
Not actually a full upsert, because we have to reindex later.
Process: 
1. Generate a uuid for the chunk
2. Generate an embedding for the text
3. Insert metadata into database
4. Increment idx counter

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
chunk : str
    This is the text content of the chunk you want to upsert
doc_name : str
    The name of the document that chunk is from. For instance, if you 
    were upserting all the chunks in an academic paper, doc_name might
    be the name of that paper

Notes
-----
If the vectors have been indexed, this de-indexes them (i.e., they need
to be indexed again). Currentoy, we handle this by setting hnsw to 
nothing so that it gets caught later in search.
"""
function upsert_chunk(corpus::Corpus, chunk::String, doc_name::String)
    if !isnothing(corpus.hnsw)
        corpus.hnsw = nothing
    end

    embedding = embed(corpus.embedder, chunk)
    push!(corpus.data, embedding)

    # insert metadata into SQLite
    DBInterface.execute(corpus.db, """
        INSERT INTO metadata (idx, doc_name, chunk) 
        VALUES (?, ?, ?)
        """,
        (corpus.next_idx, doc_name, chunk)
    )

    corpus.next_idx += 1;
end

"""
    function upsert_document(corpus::Corpus, doc_text::String, doc_name::String)

Upsert a whole document (i.e., long string).
Does so by splitting the document into appropriately-sized chunks so no chunk exceeds
the embedder's tokenization max sequence length, while prioritizing sentence endings.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
doc_text : str
    A long string you want to upsert. We will break this into chunks and
    upsert each chunk.
doc_name : str
    The name of the document the content is from
"""
function upsert_document(corpus::Corpus, doc_text::String, doc_name::String)
    chunks = chunkify(
        doc_text, 
        corpus.embedder.tokenizer, 
        corpus.max_seq_len
    )
    for chunk in chunks
        upsert_chunk(corpus, chunk, doc_name)
    end
end

"""
    function index(corpus::Corpus)

Constructs the HNSW vector index from the data available.
Must be run before searching.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
"""
function index(corpus::Corpus)
    corpus.hnsw = HierarchicalNSW(
            corpus.data; 
            efConstruction=100, M=16, ef=50
    )
    add_to_graph!(corpus.hnsw)
end

"""
    function search(corpus::Corpus, query::String, k::Int=5)

Performs approximate nearest neighbor search to find the items in the vector
index closest to the query.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
query : str
    The text you want to search, e.g. your question
    We embed this and perform semantic retrieval against the vector db
k : int
    The number of nearest-neighbor vectors to fetch
"""
function search(corpus::Corpus, query::String, k::Int=5)
    if isnothing(corpus.hnsw)
        index(corpus)
    end

    embedding = embed(corpus.embedder, query)
    idxs, distances = knn_search(corpus.hnsw, [embedding], k)

    # idxs come back as a vector of hexadecimals, so convert to readable ints
    idx_list = [Int(x) for x in idxs[1]]

    # execute query against SQLite DB
    idx_list_str = join(idx_list, ",")
    query_result = DBInterface.execute(
        corpus.db, 
        "SELECT * FROM metadata WHERE idx IN ($idx_list_str)"
    )
    
    # ensure the query result is ordered like the indices (by distance)
    df = DataFrame(query_result)
    sort_order = Dict(idx => order for (order, idx) in enumerate(idx_list))
    df.sort_order = [get(sort_order, idx, NaN) for idx in df.idx]
    ordered_df = sort(df, :sort_order)

    doc_names = String[]
    chunks = String[]
    for row in eachrow(ordered_df)
        push!(doc_names, row[:doc_name])
        push!(chunks, row[:chunk])
    end

    return idx_list, doc_names, chunks, distances
end

end