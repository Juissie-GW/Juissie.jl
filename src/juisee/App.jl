#=
To launch: start julia in from src directory, 
   julia>using GenieFramework
   julia>Genie.loadapp()
it willtake some time, once it said "Ready!", open a browser and enter 127.0.0.1:8000

for test, enter "tiny" and hit the button, then try other words
=#

module Frontend
include("Backend.jl")
using .Backend 
using GenieFramework
using SQLite
using HNSW
using UUIDs
using DataFrames
include("Embedding.jl")
using .Embedding
include("TextUtils.jl")
using .TextUtils
@genietools

corpus = Corpus()

#Upserting for testing purposes, replace with either an upload module for a file, or with an external files, to be uploaded
upsert_chunk(corpus, "Hold me closer, tiny dancer.", "doc1")
upsert_chunk(corpus, "Count the headlights on the highway.", "doc1")
upsert_chunk(corpus, "Lay me down in sheets of linen.", "doc2")
upsert_chunk(corpus, "Peter Piper picked a peck of pickled peppers. A peck of pickled peppers, Peter Piper picked.", "doc2")

#reactive part of the frontent, @app contains reactive code, @in and @out variables are both exposed to UI, 
#@in variables are those that can be changed by UI, and @out are those that changed only by Julia code, i.e. read-only from UI
@app begin
    @in userinput = false
    @in search = ""
    @in searching = false
    @in button_pressed = false
    @out idx_list = []
    @out doc_names = []
    @out chunks = []
    @out distances = []
    @onchange userinput begin
        @info "Searching for $search"
        button_pressed = true
        idx_list, doc_names, chunks, distances = Backend.search(
            corpus, 
            search, 
            2
        )
        button_pressed = false
        #console output to see values, irrelevant for the final version, keep for debugging
        @info "value of $idx_list, $doc_names, $chunks, $distances"
    end
end

function ui()
    [
    h2("Julia Team Demo")
    input("search", :search, style="width:500px")
    button("Search", @click("button_pressed = true"), loading=:button_pressed)
    p("{{idx_list}}")
    p("{{doc_names}}")
    p("{{chunks}}")
    p("{{distances}}")
    ]
end

#simple way to run the app, probably will be changed depending on deployment/presentation method
@page("/", "App.jl.html")
Server.up()
end

