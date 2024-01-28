include("FileReaders/FileReader.jl")

function main()
    result = Nocab.getAllTextInFile("nocab.txt")
    print(result)
end #function main()

main()
