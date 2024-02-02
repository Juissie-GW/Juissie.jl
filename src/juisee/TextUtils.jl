# TextUtils.jl

module TextUtils

using Transformers
using Transformers.TextEncoders

export chunkify

"""
    function sentence_splitter(text::String)

Divides a provided text (e.g. paragraph) into sentences.
"""
function sentence_splitter(text::String)
    regex = r"(?<=[.!?])\s+|\Z"
    sentences = split(text, regex)
    return filter(s -> !isempty(s), sentences)
end

"""
    function chunkify(text::String, tokenizer, sequence_length::Int=512)

Splits a provided text (e.g. paragraph) into chunks that are each as many sentences
as possible while keeping the chunk's token lenght below the sequence_length.
This ensures that each chunk can be fully encoded by the embedder.
"""
function chunkify(text::String, tokenizer, sequence_length::Int=512)
    sentences = sentence_splitter(text)
    sentence_token_lengths = [
        length(encode(tokenizer, sentence).segment)
        for sentence in sentences
    ]

    chunks = []
    current_chunk = []
    current_length = 0
    for (i, sentence) in enumerate(sentences)
        token_length = sentence_token_lengths[i]
        if current_length + token_length <= sequence_length
            push!(current_chunk, sentence)
            current_length += token_length
        else
            if !isempty(current_chunk)
                push!(chunks, join(current_chunk, " "))
            end
            current_chunk = [sentence]
            current_length = token_length
        end
    end

    if !isempty(current_chunk)
        push!(chunks, join(current_chunk, " "))
    end
    return chunks
end

end