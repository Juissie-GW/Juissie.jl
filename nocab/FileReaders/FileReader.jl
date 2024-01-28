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

function writeToFile(filename::String, contents::String)::Bool
    try
        open(filename, "w")file do
            write(file, contents)
        end # open(filename, "w") file do
        return true
    catch e
        println("ERROR: File could not be opened for writting. Filename: '$filename'\nerror: $e")
    end # try
    return false
end # function writeToFile(filename::String, contents::String)::Bool

end # module Nocab
