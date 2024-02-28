module Juissie

include("SemanticSearch/SemanticSearch.jl")
include("Generation.jl")

using .SemanticSearch
export Corpus, 
    upsert_chunk, 
    upsert_document, 
    upsert_document_from_url,
    search,
    Embedder, 
    embed,
    load_corpus

using .Generation
export OAIGenerator,
    OAIGeneratorWithCorpus,
    generate, 
    generate_with_corpus,
    upsert_chunk_to_generator,
    upsert_document_to_generator,
    upsert_document_from_url_to_generator

end
