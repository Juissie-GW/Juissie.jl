# TextUtils.jl

module TextUtils

using Transformers
using Transformers.TextEncoders
using HTTP
using Gumbo
using Cascadia

export chunkify, read_html_url

"""
    function get_files_path()

Simple function to return the path to the files subdirectory.

Example Usage
-------------
test_bin_path = get_files_path()*"test.bin"
"""
function get_files_path()
    CURR_DIR = @__DIR__
    return CURR_DIR * "/files/"
end

"""
    read_html_url(url::String, elements::Array{String})

Returns a string of text from the provided HTML elements on a webpage.

Parameters
----------
url : String
    the url you want to read
elements : Array{String}
    html elements to look for in the web page, e.g. ["h1", "p"].

Notes
-----
Defaults to extracting headers and paragraphs
"""
function read_html_url(url::String, elements::Array{String}=["h1", "h2", "p"])
    elements_str = join(elements, ", ")
    response = HTTP.get(url)
    html_content = String(response.body)
    parsed_html = Gumbo.parsehtml(html_content)
    selected_elements = eachmatch(Selector(elements_str), parsed_html.root)
    str_content = join([text(element) for element in selected_elements], " ")
    return str_content
end


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

end # module TextUtils