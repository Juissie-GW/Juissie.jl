module Juissie

include("SemanticSearch/SemanticSearch.jl")

using .SemanticSearch
export Corpus, upsert_chunk, upsert_document, search,
    Embedder, embed

end