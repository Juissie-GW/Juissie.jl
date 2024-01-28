module Nocab

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

function appendToFile(filename::String, contents::String)::Bool
    try
        open(filename, "a") do file # 'a' for append
            write(file, contents)
        end # open(filename, "w") file do
        return true
    catch e
        println("ERROR: File could not be opened for writting. Filename: '$filename'\nerror: $e")
    end # try
    return false
end # function appendToFile(filename::String, contents::String)::Bool

struct Line
    title::String
    body::String
end

function splitLine(line::String)::Line
    splits = split(line, " ||| ")
    println(splits)
    println(splits[1])
    println(splits[2])
    return Line(splits[1], splits[2])
end # function splitLine(line::String)::Line

function fakeModel(input::Line)::String
    println("Running the input through the network...")
    # processing goes here
    println("Finished vectorizing the input")
    return "SomeOutputString, maybe should be a vector of numbers instead?"
end # function fakeNetwork(input::Line)::String

function readProcessWrite(filenameToRead::String, filenameToWrite::String)
    open(filenameToRead) do inputFile
        open(filenameToWrite) do outputFile
            while !eof(inputFile)
                input::Line = splitLine(readline(inputFile))
                output = fakeModel(input)
                appendToFile(filenameToWrite, output * "\n") # TODO: Consider having the append to file add the newlines? 
                print("=======")
            end # while !eof(inputFile)
        end # open(filenameToWrite) do outputFile
    end # open(filenameToRead) do inputFile
end # function readProcessWrite(filenameToRead::String, filenameToWrite:String)

end # module Nocab
