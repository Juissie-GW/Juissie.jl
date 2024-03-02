"""Exports all the symbols defined in the SemanticSearch
directory as one SemanticSearch module"""

module SemanticSearch

include("Backend.jl")
include("Embedding.jl")
include("TextUtils.jl")

using .Backend
export Corpus,
    upsert_chunk, 
    upsert_document,
    upsert_document_from_url,
    upsert_document_from_pdf, 
    upsert_document_from_txt, 
    search, 
    load_corpus

using .Embedding
export Embedder, embed

using .TextUtils
export chunkify

end