"""Exports all the symbols defined in the SemanticSearch
directory as one SemanticSearch module"""

module SemanticSearch

include("Backend.jl")
include("Embedding.jl")
include("TextUtils.jl")

export Corpus, upsert_chunk, upsert_document, search,
    Embedder, embed,
    chunkify

end