module Juissie

include("SemanticSearch/SemanticSearch.jl")
include("Generation.jl")

using .SemanticSearch
export Corpus,
    load_corpus,
    upsert_chunk,
    upsert_document,
    upsert_document_from_url,
    upsert_document_from_pdf,
    upsert_document_from_txt,
    search,
    Embedder,
    embed,
    cosine_similarity

using .Generation
export OAIGenerator,
    OAIGeneratorWithCorpus,
    OllamaGenerator,
    OllamaGeneratorWithCorpus
    generate,
    generate_with_corpus,
    upsert_chunk_to_generator,
    upsert_document_to_generator,
    upsert_document_from_url_to_generator,
    load_OAIGeneratorWithCorpus,
    load_OllamaGeneratorWithCorpus

end
