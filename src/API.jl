module API

using HTTP
using WebIO
using JSON
using FilePathsBase

include("Generation.jl")
using .Generation

export get_corpus_names,
    handle_corpus_names,
    handle_load_generator,
    handle_generate,
    handle_create_generator,
    handle_upsert_document,
    handle_update_api_key


"""
    function simple_response(code::Int, message::String)

Helper function to throw an HTTP response with a textual message

Parameters
----------
code : Int
    status code for the response. in our case, one of the following:
        - 200 (success)
        - 500 (failure)
message : String
    the textual body you want to send
"""
function simple_response(code::Int, message::String)
    content_type_json = ["Content-Type" => "application/json"]
    if code == 200
        return HTTP.Response(
            200,
            content_type_json, 
            "{\"message\": \"$message\"}"
        )
    elseif code == 500
        return HTTP.Response(
            500,
            content_type_json,
            "{\"error\": \"$message\"}"
        )
    else
        code_str = String(code)
        throw(error("Response status code $code_str not recognized"))
    end
end


"""
    function json_response(payload)

Helper function to throw an HTTP response with a textual message

Parameters
----------
code : Int
    status code for the response. in our case, one of the following:
        - 200 (success)
        - 500 (failure)
payload : JSON body
    a JSON-ified dictionary for the response body
"""
function json_response(code::Int, payload)
    content_type_json = ["Content-Type" => "application/json"]
    return HTTP.Response(code, content_type_json, payload)
end


"""
    function get_corpus_names()

Finds the names for all the existing corpora you have locally
"""
function get_corpus_names()
    backend_files_dir = joinpath(dirname(@__FILE__), "SemanticSearch", "files")
    backend_file_names = readdir(backend_files_dir)
    backend_file_names_stripped = [splitext(f)[1] for f in backend_file_names]
    corpus_names = [replace(f, "_data" => "") for f in backend_file_names_stripped]
    corpus_names_unique = [f for f in unique(corpus_names) if f!=".DS_Store"]
    return corpus_names_unique
end


"""
    function handle_corpus_names()

Endpoint logic for pulling all the existing corpus names from local
    storage
"""
function handle_corpus_names()
    try
        corpus_names = get_corpus_names()
        response_dict = Dict("corpus_names" => corpus_names)
        payload = JSON.json(response_dict)
        return json_response(200, payload)
    catch e
        return simple_response(500, "Juissie could not find any local corpora: $e")
    end
end


"""
    function handle_load_generator(OAI_KEY::Union{String, Nothing}, request::HTTP.Request)

Endpoint logic for loading an existing OAIGeneratorWithCorpus from local
    storage

Parameters
----------
request : HTTP.Request
    the received request from the UI
OAI_KEY : Union{String, Nothing}
    the OpenAI key (can be nothing if you have one in .env)
"""
function handle_load_generator(OAI_KEY::Union{String, Nothing}, request::HTTP.Request)
    try
        corpus_name = String(request.body)
        generator = load_OAIGeneratorWithCorpus(corpus_name, OAI_KEY)
        return generator, simple_response(200, "Juissie successfully loaded the on-disk GeneratorWithCorpus '$corpus_name'")
    catch e
        return nothing, simple_response(500, "Juissie could not load the GeneratorWithCorpus: $e")
    end
end

"""
    function handle_generate(generator::GeneratorWithCorpus, request::HTTP.Request)

Endpoint logic for generating a response to a user's query using
    a OAIGeneratorWithCorpus

Parameters
----------
request : HTTP.Request
    the received request from the UI
generator : GeneratorWithCorpus
    a generator from Generation.jl
"""
function handle_generate(generator::GeneratorWithCorpus, request::HTTP.Request)
    try
        query = String(request.body)
        result, idx_list, doc_names, chunks = generate_with_corpus(generator, query, 10, 0.7)
        response_dict = Dict(
            "result" => result,
            "doc_names" => unique(doc_names)
        )
        payload = JSON.json(convert(Dict{String, Any}, response_dict))
        return json_response(200, payload)
    catch e
        return simple_response(500, "Juissie could not generate a response: $e")
    end
end

"""
    function handle_create_generator(OAI_KEY::Union{String, Nothing}, request::HTTP.Request)

Endpoint logic for creating a new OAIGeneratorWithCorpus

Parameters
----------
request : HTTP.Request
    the received request from the UI
OAI_KEY : Union{String, Nothing}
    the OpenAI key (can be nothing if you have one in .env)
"""
function handle_create_generator(OAI_KEY::Union{String, Nothing}, request::HTTP.Request)
    try
        corpus_name = String(request.body)
        if corpus_name == ""
            generator = OAIGeneratorWithCorpus(nothing, OAI_KEY)
            return generator, simple_response(200, "Juissie successfully created an in-memory GeneratorWithCorpus")
        else
            generator = OAIGeneratorWithCorpus(corpus_name, OAI_KEY)
            return generator, simple_response(200, "Juissie successfully created on-disk GeneratorWithCorpus '$corpus_name'")
        end
    catch e
        return nothing, simple_response(500, "Juissie could not creat the GeneratorWithCorpus: $e")
    end
end

"""
    function handle_upsert_document(generator::GeneratorWithCorpus, request::HTTP.Request)

Endpoint logic for reading a url page and upserting its contents into
    the backend

Parameters
----------
request : HTTP.Request
    the received request from the UI
generator : GeneratorWithCorpus
    a generator from Generation.jl
"""
function handle_upsert_document(generator::GeneratorWithCorpus, request::HTTP.Request)
    try
        response_dict = JSON.parse(String(request.body))
        url = response_dict["url"]
        document_name = response_dict["doc_title"]
        upsert_document_from_url_to_generator(generator, url, document_name)
        return simple_response(200, "Document '$document_name' has been upserted successfully")
    catch e
        return simple_response(500, "Juissie could not upsert document: $e")
    end
end

"""
    function handle_update_api_key(request::HTTP.Request)

Endpoint logic for updating the OAI_KEY global variable

Parameters
----------
request : HTTP.Request
    the received request from the UI
"""
function handle_update_api_key(request::HTTP.Request)
    try
        key = String(request.body)
        if !check_oai_key_format(key)
            throw(error("OpenAI key does not match the expected format."))
        end
        return key, simple_response(200, "Your API Key has been updated successfully")
    catch e
        payload = JSON.json(Dict("error" => "Juissie could not update the API key: $(e.msg)"))
        return nothing, json_response(500, payload)
    end
end

end