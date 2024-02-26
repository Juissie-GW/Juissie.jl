module Juissie

include("SemanticSearch/SemanticSearch.jl")
include("Generation.jl")

using .SemanticSearch
export Corpus, 
        load_corpus,
        upsert_chunk, 
        upsert_document, 
        upsert_pdf_document, 
        upsert_txt_document, 
        search,
    Embedder, 
        embed

using .Generation
export OAIGenerator, generate

end