# Generation.jl

module Generation

using HTTP
using JSON
using DotEnv

include("SemanticSearch/SemanticSearch.jl")
using .SemanticSearch

export OAIGenerator,
    OAIGeneratorWithCorpus,
    generate, 
    generate_with_corpus,
    upsert_chunk_to_generator,
    upsert_document_to_generator,
    upsert_document_from_url_to_generator,
    load_OAIGeneratorWithCorpus


const OptionalContext = Union{Vector{String}, Nothing}
abstract type Generator end
abstract type GeneratorWithCorpus <: Generator end

"""
    struct OAIGenerator

A struct for handling natural language generation via OpenAI's
gpt-3.5-turbo completion endpoint.

Attributes
----------
url : String
    the URL of the OpenAI API endpoint
header : Vector{Pair{String, String}}
    key-value pairs representing the HTTP headers for the request
body_dict : Dict{String, Any}
    this is the JSON payload to be sent in the body of the request

Notes
-----
All natural language generation should be done via a "Generator"
object of some kind for consistency. In the future, if we 
decide to host a model locally or something, we might do that
via a HFGenerator struct.
"""
struct OAIGenerator <: Generator
    url::String
    header::Vector{Pair{String, String}}
    body_dict::Dict{String,Any}
end


"""
    struct OAIGeneratorWithCorpus

Like OAIGenerator, but has a corpus attached.

Attributes
----------
url : String
    the URL of the OpenAI API endpoint
header : Vector{Pair{String, String}}
    key-value pairs representing the HTTP headers for the request
body_dict : Dict{String, Any}
    this is the JSON payload to be sent in the body of the request
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
"""
struct OAIGeneratorWithCorpus <: GeneratorWithCorpus
    url::String
    header::Vector{Pair{String, String}}
    body_dict::Dict{String,Any}
    corpus::Corpus
end


"""
    function OAIGenerator(auth_token::Union{String, Nothing})

Initializes an OAIGenerator struct.

Parameters
----------
auth_token :: Union{String, Nothing}
    this is your OPENAI API key. You can either pass it explicitly as a string
    or leave this argument as nothing. In the latter case, we will look in your
    environmental variables for "OAI_KEY"
"""
function OAIGenerator(auth_token::Union{String, Nothing}=nothing)
    if isnothing(auth_token)
        path_to_env = joinpath(@__DIR__, "..", ".env")
        DotEnv.config(path_to_env)
        auth_token = ENV["OAI_KEY"]
    end

    url = "https://api.openai.com/v1/chat/completions"
    header = [
        "Content-Type" => "application/json",
        "Authorization" => "Bearer $auth_token"
    ]
    body_dict = Dict(
        "model" => "gpt-3.5-turbo"
    )

    return OAIGenerator(url, header, body_dict)
end

"""
    function OAIGeneratorWithCorpus(auth_token::Union{String, Nothing}=nothing, corpus::Corpus)

Initializes an OAIGeneratorWithCorpus.

Parameters
----------
corpus_name : str or nothing
    the name that you want to give the database
    optional. if left as nothing, we use an in-memory database
auth_token :: Union{String, Nothing}
    this is your OPENAI API key. You can either pass it explicitly as a string
    or leave this argument as nothing. In the latter case, we will look in your
    environmental variables for "OAI_KEY"
embedder_model_path : str
    a path to a HuggingFace-hosted model
    e.g. "BAAI/bge-small-en-v1.5"
max_seq_len : int
    The maximum number of tokens per chunk.
    This should be the max sequence length of the tokenizer
"""
function OAIGeneratorWithCorpus(
        corpus_name::Union{String, Nothing}=nothing,
        auth_token::Union{String, Nothing}=nothing,
        embedder_model_path::String="BAAI/bge-small-en-v1.5", 
        max_seq_len::Int=512
    )
    base_generator = OAIGenerator(auth_token)
    corpus = Corpus(corpus_name, embedder_model_path, max_seq_len)
    new_generator = OAIGeneratorWithCorpus(
        base_generator.url, base_generator.header, base_generator.body_dict, corpus
    )
    return new_generator
end

"""
    function load_OAIGeneratorWithCorpus(corpus_name::String, auth_token::Union{String, Nothing}=nothing)

Loads an existing corpus and uses it to initialize an GeneratorWithCorpus

Parameters
----------
corpus_name : str
    the name that you want to give the database
auth_token :: Union{String, Nothing}
    this is your OPENAI API key. You can either pass it explicitly as a string
    or leave this argument as nothing. In the latter case, we will look in your
    environmental variables for "OAI_KEY"

Notes
-----
corpus_name is ordered first because Julia uses positional arguments and 
auth_token is optional.
"""
function load_OAIGeneratorWithCorpus(
        corpus_name::String,
        auth_token::Union{String, Nothing}=nothing
    )
    base_generator = OAIGenerator(auth_token)
    corpus = load_corpus(corpus_name)
    new_generator = OAIGeneratorWithCorpus(
        base_generator.url, 
        base_generator.header, 
        base_generator.body_dict, 
        corpus
    )
    return new_generator
end


"""
    function build_full_query(query::String, context::OptionalContext=nothing)

Given a query and a list of contextual chunks, construct a full query
incorporating both.

Parameters
----------
query : String
    the main instruction or query string
context : OptionalContext, which is Union{Vector{String}, Nothing}
    optional list of chunks providing additional context for the query

Notes
-----
We use the Alpaca prompt, found here: https://github.com/tatsu-lab/stanford_alpaca
with minor modifications that reflect our response preferences.
"""
function build_full_query(query::String, context::OptionalContext=nothing)
    prompt_preferences = """
    Write concisely.
    In your response, do not include any parenthetical citations (e.g. "[32]").
    """
    
    full_query = """
    Below is an instruction that describes a task. Write a response that appropriately completes the request.
    $prompt_preferences

    ### Instruction:
    $query
    """

    if !isnothing(context)
        context_str = join(["- " * s for s in context], "\n")
        full_query = """
        Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.
        $prompt_preferences

        ### Instruction:
        $query
        
        ### Input:
        $context_str
        
        ### Response:
        """
    end

    return full_query
end

"""
    generate(generator::Union{OAIGenerator, Nothing}, query::String, context::OptionalContext=nothing, temperature::Float64=0.7)

Generate a response based on a given query and optional context using the specified OAIGenerator. This function constructs a full query, sends it to the OpenAI API, and returns the generated response.

Parameters
----------
generator : Union{OAIGenerator, Nothing}
    an initialized generator (e..g OAIGenerator)
    leaving this as a union with nothing to note that we may want to support other 
    generator types in the future (e.g. HFGenerator, etc.)
query : String
    the main instruction or query string. This is basically your question
context : OptionalContext, which is Union{Vector{String}, Nothing}
    optional list of contextual chunk strings to provide the generator additional 
    context for the query. Ultimately, these will be coming from our vector DB
temperature : Float64
    controls the stochasticity of the output generated by the model
"""
function generate(
        generator::Union{Generator, GeneratorWithCorpus}, 
        query::String, 
        context::OptionalContext=nothing, 
        temperature::Float64=0.7
    )
    # build full query from query and context
    full_query = build_full_query(query, context)
    
    if isa(generator, Union{OAIGenerator, OAIGeneratorWithCorpus})
        generator.body_dict["temperature"] = temperature
        generator.body_dict["messages"] = [
            Dict(
                "role" => "user", 
                "content" => full_query
            )
        ]
        body = JSON.json(generator.body_dict)
        response = HTTP.request("POST", generator.url, generator.header, body)
    
        if response.status == 200
            response_str = String(response.body)
            parsed_dict = JSON.parse(response_str)
            result = parsed_dict["choices"][1]["message"]["content"]
        else
            error("Request failed with status code $(response.status): $(String(response.body))")
        end
    else
        # if we have time, we can use this to generate via something locally-hosted
        throw(ArgumentError("generator is not of a supported type."))
    end

    return result
end

"""
    function generate_with_corpus(generator::Union{OAIGenerator, Nothing}, corpus::Corpus, query::String, k::Int=5, temperature::Float64=0.7)

Parameters
----------
generator : Union{OAIGenerator, Nothing}
    an initialized generator (e..g OAIGenerator)
    leaving this as a union with nothing to note that we may want to support other 
    generator types in the future (e.g. HFGenerator, etc.)
corpus : an initialized Corpus object
    the corpus / "vector database" you want to use
query : String
    the main instruction or query string. This is basically your question
k : int
    The number of nearest-neighbor vectors to fetch from the corpus to build your context
temperature : Float64
    controls the stochasticity of the output generated by the model
"""
function generate_with_corpus(
        generator::GeneratorWithCorpus, 
        query::String, 
        k::Int=5, 
        temperature::Float64=0.7
    )
    # search corpus
    idx_list, doc_names, chunks, distances = search(generator.corpus, query, k)
    result = generate(generator, query, chunks, temperature)
    return result, idx_list, doc_names, chunks
end

"""
    function upsert_chunk_to_generator(generator::GeneratorWithCorpus, chunk::String, doc_name::String)

Equivalent to Backend.upsert_chunk, but takes a GeneratorWithCorpus
instead of a Corpus.

Parameters
----------
generator : any struct that subtypes GeneratorWithCorpus
    the generator (with corpus) you want to use
chunk : str
    This is the text content of the chunk you want to upsert
doc_name : str
    The name of the document that chunk is from. For instance, if you 
    were upserting all the chunks in an academic paper, doc_name might
    be the name of that paper

Notes
-----
One would expect Julia's multiple dispatch to allow us to call this
upsert_chunk, but not so. The conflict arises in Juissie, where 
we would have both SemanticSearch and Generation exporting 
upsert_chunk. This means any uses of it in Juissie must be 
qualified, and without doing so, neither actually gets defined.
"""
function upsert_chunk_to_generator(
        generator::GeneratorWithCorpus, 
        chunk::String, 
        doc_name::String
    )
    upsert_chunk(generator.corpus, chunk, doc_name)
end

"""
    function upsert_document_to_generator(generator::GeneratorWithCorpus, doc_text::String, doc_name::String)

Equivalent to Backend.upsert_document, but takes a GeneratorWithCorpus
instead of a Corpus.

Parameters
----------
generator : any struct that subtypes GeneratorWithCorpus
    the generator (with corpus) you want to use
doc_text : str
    A long string you want to upsert. We will break this into chunks and
    upsert each chunk.
doc_name : str
    The name of the document the content is from

Notes
-----
See note for upsert_chunk_to_generator - same idea.
"""
function upsert_document_to_generator(
        generator::GeneratorWithCorpus, 
        doc_text::String, 
        doc_name::String
    )
    upsert_document(generator.corpus, doc_text, doc_name)
end

"""
    function upsert_document_from_url_to_generator(generator::GeneratorWithCorpus, url::String, doc_name::String, elements::Array{String}=["h1", "h2", "p"])

Equivalent to Backend.upsert_document_from_url, but takes a 
GeneratorWithCorpus instead of a Corpus.

Parameters
----------
generator : any struct that subtypes GeneratorWithCorpus
    the generator (with corpus) you want to use
url : String
    The url you want to scrape for text
doc_name : str
    The name of the document the content is from
elements : Array{String}
    A list of HTML elements you want to pull the text from

Notes
-----
See note for upsert_chunk_to_generator - same idea.
"""
function upsert_document_from_url_to_generator(
        generator::GeneratorWithCorpus, 
        url::String, 
        doc_name::String, 
        elements::Array{String}=["h1", "h2", "p"]
    )
    upsert_document_from_url(generator.corpus, url, doc_name, elements)
end


end