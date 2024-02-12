module Juissie

include("SemanticSearch/SemanticSearch.jl")

export Corpus, upsert_chunk, upsert_document, search,
    Embedder, embed

end