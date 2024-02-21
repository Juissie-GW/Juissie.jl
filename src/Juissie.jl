module Juissie

include("SemanticSearch/SemanticSearch.jl")
include("Generation.jl")

using .SemanticSearch
export Corpus, upsert_chunk, upsert_document, search,
    Embedder, embed, load_corpus

using .Generation
export OAIGenerator, generate

end