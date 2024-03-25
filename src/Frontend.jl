using Blink
using HTTP
using WebIO
using Sockets

include("API.jl")
using .API


# these are placeholders that we will modify in the request handler
global generator = nothing
global OAI_KEY = nothing


"""
    function request_handler(request::HTTP.Request)

Outlines the Julia logic for the HTTP requests we want to use
in our UI. For the most part, this can be summarized as "stuff the 
buttons do."

Parameters
----------
request : HTTP.Request
    the request we're routing/handling
"""
function request_handler(request::HTTP.Request)
    # just referencing the global variables we already have
    # to ensure we can use them like global vars in this
    # function
    global generator
    global OAI_KEY

    method = request.method
    target = request.target
    
    # our internal API logic is written in Julia, so this
    # routes the request to the appropriate API function
    # in API.jl
    if method == "GET" && occursin("/corpus_names", target)
        return handle_corpus_names()
    elseif method == "POST" && occursin("/load_generator", target)
        gen, response = handle_load_generator(OAI_KEY, request)
        if !isnothing(gen)
            generator = gen
        end
        return response
    elseif method == "POST" && occursin("/generate", target)
        return handle_generate(generator, request)
    elseif method == "POST" && occursin("/create_generator", target)
        gen, response = handle_create_generator(OAI_KEY, request)
        if !isnothing(gen)
            generator = gen
        end
        return response
    elseif method == "POST" && occursin("/upsert_document", target)
        return handle_upsert_document(generator, request)
    elseif method == "POST" && occursin("/update_api_key", target)
        key, response = handle_update_api_key(request)
        if !isnothing(key)
            OAI_KEY = key
        end
        return response
    end
end


"""
    function cors_middleware(request::HTTP.Request)

This is a handler that every request passes through. It handles 
preflight requests and sets the CORS header so we don't have frustrating 
type/fetch errors.

Parameters
----------
request : HTTP.Request
    the request we're routing/handling

Notes
-----
CORS stands for cross-origin resource sharing. This ends up being important
    because browsers usually enforce a same-origin policy. This pattern is 
    based on the docs here: https://juliaweb.github.io/HTTP.jl/stable/examples/
"""
function cors_middleware(request::HTTP.Request)
    # specify things like which methods are allowed (e.g. get, post)
    cors_opt_headers = [
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Allow-Headers" => "Content-Type",
        "Access-Control-Allow-Methods" => "POST, GET, OPTION",
    ]
    if request.method == "OPTIONS"
        return HTTP.Response(204, cors_opt_headers) # successful request, but no content
    end
    
    # if the request is GET or POST, then have request_handler
    # route it to the appropriate Julia function
    response = request_handler(request)
    for (k, v) in cors_opt_headers
        HTTP.setheader(response, k => v)
    end
    return response
end


"""
    function create_window()

Pulls in the HTML and CSS files to create our UI window.

Notes
-----
TODO: consider a light theme
"""
function create_window()
    html_content = read("src/index.html", String)
    window = Window()
    body!(window, html_content)
    load!(window, "src/style.css")
    return window
end


Blink.AtomShell.init()
window = create_window()
HTTP.serve!(cors_middleware, Sockets.localhost, 8000)

Blink.@async begin
    while true
        sleep(0.01)
        Blink.process_events()
    end
end

while true
    # this is hacky but it's the only way I could get the window to 
    # stay open. otherwise it just closes as soon as it loads
    # all the elements
    sleep(1)
end
