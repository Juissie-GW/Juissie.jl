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
A simple script that allows a user to split a large file into multiple smaller files. 
This will create splits # of children files, each with a file size ~1/splits 
of the origional target file.

Parameters
----------
fileToSplit : String
    The name of the file to read and split into multiple parts.
    If an absolute file path is given then that will be
    used. Otherwise, relative file paths are evaluated from the location that
    the `julia` command was run from (typically the root level of this project)
outputFileNameBase : String
    The template for the name of the children split-out files. 
    Each split out file with have the format of <outputFileNameBase>_<#> 
    where # starts at 1 and increments by 1 for each subsequent file. 
    There will be `splits` number of children files
splits : Int
    How many children files should be created?
"""
function splitFileIntoParts(fileToSplit::String, outputFileNameBase::String, splits::Int)
    # Get the size of the target file
    readFile::IOStream = open(fileToSplit)
    readFileSize::Int = stat(readFile).size
    close(readFile)
    # Calculate the size of each split file
    targetOutputSize::Int = floor(readFileSize / splits)

    # Loop over every lin in target file. Add line to a split file
    # Once the split file is large enough, move to new split file
    outputFilePart::Int = 1
    sizeAdded::Int = 0
    for line in eachline(fileToSplit)
        outputFileName = outputFileNameBase * "_" * string(outputFilePart)
        lineToAdd::String = line * "\n"
        Nocab.appendToFile(outputFileName, lineToAdd)
        sizeAdded = sizeAdded + sizeof(lineToAdd) # takes care of non-ascii characters like ∀

        if (sizeAdded >= targetOutputSize)
            # If we've added enough to the split file
            println("Finished splitting file: " * outputFileName)
            outputFilePart = outputFilePart + 1
            sizeAdded = 0
        end # if(sizeAdded >= maxSize)
    end # for line in eachline(filename)

end # function splitFileIntoParts


"""
Open the provided filename, load all the data into memory, and return.
This function will also manage the file socket open(...) close(...) properly.
If there was an error in opening or reading the file then the empty 
string will be returned

Parameters
----------
filename: String
    The name of the file to open. Relative file paths are evaluated from
    the directory where the `julia` command was run. Typically the root level
    of the project

Returns: String
    The entire contets of the file, or an empty string if there was an issue
"""
function getAllTextInFile(filename::String)::String
    try
        file = open(filename, "r")
        result = read(file, String)
        close(file)
        return result
    catch
        println("ERROR: File could not be opend (does it exist?). Filename: '$filename'\nerror: $e")
    end # try
    return "" # return empty string if file could NOT be read
end # function getAllTextInFile(filename:string)

"""
Append the given `contents` into a file specified at `filename`.
A new file will be created if `filename` doesn't already exist.

NOTE: No '\n' newline character will be appended. It is the 
caller's responsibility to decide if the `contents` should have a
'\n' newline character or not. 

Parameters
---------
filename: String
    The name of the file to open. Relative file paths are evaluated from
    the directory where the `julia` command was run. Typically the root level
    of the project
contents: String
    The exact text to append into the file.
"""
function appendToFile(filename::String, contents::String)::Bool
    try
        touch(filename) # Create file if it doesn't already exist
        open(filename, "a") do file # 'a' for append
            write(file, contents)
        end # open(filename, "w") file do
        return true
    catch e
        println("ERROR: File could not be opened for writting. Filename: '$filename'\nerror: $e")
    end # try
    return false
end # function appendToFile(filename::String, contents::String)::Bool

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