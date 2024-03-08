# Backend.jl

module Backend

using SQLite
using HNSW
using UUIDs
using DataFrames
using Serialization
using JSON

include("Embedding.jl")
using .Embedding
include("TextUtils.jl")
using .TextUtils
include("DataReader/PdfReader.jl")
using .PdfReader
include("DataReader/TxtReader.jl")
using .TxtReader

CURR_DIR = @__DIR__

export Corpus,
    upsert_chunk,
    upsert_document,
    upsert_document_from_url,
    upsert_document_from_pdf,
    upsert_document_from_txt,
    search,
    load_corpus

"""
    struct Corpus

Basically a vector database. It will have these attributes:
1. a relational database (SQLite)
2. a vector index (HNSW)
3. an embedder (via Embedding.jl)

Attributes
----------
corpus_name : String or Nothing
    this is the name of your corpus and will be used to access saved 
        corpuses
    if Nothing, we can't save/load and everything will be in-memory
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
    corpus_name::Union{String,Nothing}
    db::SQLite.DB
    hnsw::Union{HNSW.HierarchicalNSW,Nothing}
    embedder::Embedding.Embedder
    max_seq_len::Int64
    data::Vector{Any}
    next_idx::Int64
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
function Corpus(
    corpus_name::Union{String,Nothing} = nothing,
    embedder_model_path::String = "BAAI/bge-small-en-v1.5",
    max_seq_len::Int = 512,
)
    embedder = Embedder(embedder_model_path)

    if isnothing(corpus_name)
        db = SQLite.DB() # in-memory db
    else
        db_path = "$(CURR_DIR)/files/$(corpus_name).db"
        if isfile(db_path)
            # file exists
            @warn "A corpus by this name already exists. Do you want to proceed? Doing so will overwrite the existing corpus artifacts. [y/n]"
            user_input = readline()
            if user_input == "y"
                # delete it
                rm(db_path)
            elseif user_input == "n"
                println("Corpus creation failed; try a different corpus name.")
                return
            else
                println("Invalid input. Please enter 'y' for yes or 'n' for no.")
            end
        end
        db = SQLite.DB(db_path)
    end

    DBInterface.execute(db, "DROP TABLE IF EXISTS metadata")
    DBInterface.execute(
        db,
        """
CREATE TABLE metadata (
    idx INT PRIMARY KEY,
    doc_name TEXT,
    chunk TEXT
)
""",
    )

    # don't initialize hnsw yet because it needs initial features
    hnsw = nothing

    # if not in-memory only, save info about the corpus as a json
    if !isnothing(corpus_name)
        corpus_data =
            Dict("embedder_model_path" => embedder_model_path, "max_seq_len" => max_seq_len)
        json_str = JSON.json(corpus_data)
        corpus_data_path = "$(CURR_DIR)/files/$(corpus_name)_data.json"
        # test if the hnsw file exists
        if isfile(corpus_data_path)
            # file exists ; delete it
            rm(corpus_data_path)
        end
        open(corpus_data_path, "w") do file
            write(file, json_str)
        end
    end

    return Corpus(corpus_name, db, hnsw, embedder, max_seq_len, [], 1)
end

"""
    function load_corpus(corpus_name)

Loads an already-initialized corpus from its associated "artifacts" (relational
database, vector index, and informational json).

Parameters
----------
corpus_name : str
    the name of your EXISTING vector database
"""
function load_corpus(corpus_name::String)
    try
        db_path = "$(CURR_DIR)/files/$(corpus_name).db"
        db = SQLite.DB(db_path)
        hnsw_path = "$(CURR_DIR)/files/$(corpus_name).bin"
        hnsw = open(deserialize, hnsw_path)

        # get corpus info from associated json
        corpus_data_path = "$(CURR_DIR)/files/$(corpus_name)_data.json"
        corpus_data = open(corpus_data_path, "r") do file
            JSON.parse(read(file, String))
        end
        embedder_model_path = corpus_data["embedder_model_path"]
        embedder = Embedder(embedder_model_path)
        max_seq_len = corpus_data["max_seq_len"]

        return Corpus(corpus_name, db, hnsw, embedder, max_seq_len, [], 1)
    catch e
        if hasproperty(e, :msg)
            throw(ArgumentError("Loading failed; corpus name not found.\n" + e.msg))
        else
            throw(ArgumentError("Loading failed; corpus name not found."))
        end
    end
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
    DBInterface.execute(
        corpus.db,
        """
INSERT INTO metadata (idx, doc_name, chunk) 
VALUES (?, ?, ?)
""",
        (corpus.next_idx, doc_name, chunk),
    )

    corpus.next_idx += 1
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
    chunks = chunkify(doc_text, corpus.embedder.tokenizer, corpus.max_seq_len)
    for chunk in chunks
        upsert_chunk(corpus, chunk, doc_name)
    end
end

"""
    function upsert_document(corpus::Corpus, documents::Vector{String}, doc_name::String)

Upsert a collection of documents (i.e., a vector of long strings).
Does so by upserting each entry of the provided documents vector (which in turn will
chunkify, each document further into appropriately sized chunks).

See the upsert_document(...) above for more details

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
documents : Vector{String}
    a collection of long strings to upsert.
doc_name : str
    The name of the document the content is from
"""
function upsert_document(corpus::Corpus, documents::Vector{String}, doc_name::String)
    for doc::String in documents
        upsert_document(corpus, doc, doc_name)
    end
end

"""
    function upsert_document_from_url(corpus::Corpus, url::String, doc_name::String, elements::Array{String}=["h1", "h2", "p"])

Extracts element-tagged text from HTML and upserts as a document.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
url : String
    The url you want to scrape for text
doc_name : str
    The name of the document the content is from
elements : Array{String}
    A list of HTML elements you want to pull the text from
"""
function upsert_document_from_url(
    corpus::Corpus,
    url::String,
    doc_name::String,
    elements::Array{String} = ["h1", "h2", "p"],
)
    doc_text = read_html_url(url, elements)
    upsert_document(corpus, doc_text, doc_name)
end

"""
    function upsert_document_from_pdf(corpus::Corpus, filePath::String, doc_name::String)

Upsert all the data in a PDF file into the provided corpus.
See the upsert_document(...) above for more details.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
filePath : String
    The path to the PDF file to read
doc_name : str
    The name of the document the content is from
"""
function upsert_document_from_pdf(corpus::Corpus, filePath::String, doc_name::String)
    upsert_document(corpus, PdfReader.getAllTextInPDF(filePath), doc_name)
end

"""
    function upsert_document_from_txt(corpus::Corpus, filePath::String, doc_name::String)

Upsert all the data from the text file into the provided corpus.

Parameters
----------
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
filePath : String
    The path to the txt file to read
doc_name : str
    The name of the document the content is from
"""
function upsert_document_from_txt(corpus::Corpus, filePath::String, doc_name::String)
    upsert_document(corpus, TxtReader.getAllTextInFile(filePath), doc_name)
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
    corpus.hnsw = HierarchicalNSW(corpus.data; efConstruction = 100, M = 16, ef = 50)
    add_to_graph!(corpus.hnsw)

    if !isnothing(corpus.corpus_name)
        # we have passed a name for the corpus, which means we're not
        # doing in-memory only.
        file_path = "$(CURR_DIR)/files/$(corpus.corpus_name).bin"

        # test if the hnsw file exists
        if isfile(file_path)
            # file exists ; delete it
            rm(file_path)
        end

        # now serialize the vector index
        open(file_path, "w") do file
            serialize(file, corpus.hnsw)
        end
    end
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
function search(corpus::Corpus, query::String, k::Int = 5)
    if isnothing(corpus.hnsw)
        index(corpus)
    end

    embedding = embed(corpus.embedder, query)
    idxs, distances = knn_search(corpus.hnsw, [embedding], k)

    # for some reason idxs come back as a vector of hexadecimals, 
    # so convert to readable ints
    idx_list = [Int(x) for x in idxs[1]]

    # execute query against SQLite DB
    idx_list_str = join(idx_list, ",")
    query_result = DBInterface.execute(
        corpus.db,
        "SELECT * FROM metadata WHERE idx IN ($idx_list_str)",
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
