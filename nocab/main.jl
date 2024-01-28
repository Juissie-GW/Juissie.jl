include("FileReaders/FileReader.jl")

function main()
    Nocab.readProcessWrite("nocab.txt", "output.txt")
    # result = Nocab.getAllTextInFile("nocab.txt")
    # print(result)
end #function main()

main()
