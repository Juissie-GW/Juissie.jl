# TextUtils.jl

module TextUtils

using Transformers
using Transformers.TextEncoders

export chunkify

"""
    function sentence_splitter(text::String)

Uses basic regex to divide a provided text (e.g. paragraph) into sentences.

Parameters
----------
text : String
    The text you want to split into sentences.
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

Parameters
----------
text : String
    The text you want to split into chunks.
tokenizer : a tokenizer object, e.g. BertTextEncoder
    The tokenizer you will be using
sequence_length : Int
    The maximum number of tokens per chunk.
    Ideally, should correspond to the max sequence length of the tokenizer

Example Usage
-------------
    >>> chunkify(
        '''Hold me closer, tiny dancer. Count the headlights on the highway. Lay me down in sheets of linen. Peter Piper picked a peck of pickled peppers. A peck of pickled peppers Peter Piper picked.
        ''', 
        corpus.embedder.tokenizer, 
        20
    )

    4-element Vector{Any}:
    "Hold me closer, tiny dancer. Count the headlights on the highway."
    "Lay me down in sheets of linen."
    "Peter Piper picked a peck of pickled peppers."
    "A peck of pickled peppers Peter Piper picked."
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