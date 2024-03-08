module TxtReader

export getAllTextInFile


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

    # Loop over every line in target file. Add line to a split file
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
        println(
            "ERROR: Encountered error when reading file (does it exist?). Filename: '$filename'\nerror: $e",
        )
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
        println(
            "ERROR: File could not be opened for writting. Filename: '$filename'\nerror: $e",
        )
    end # try
    return false
end # function appendToFile(filename::String, contents::String)::Bool

end # module TxtReader
