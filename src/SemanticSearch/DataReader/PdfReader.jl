
module PdfReader

using PDFIO

export getAllTextInPDF, getAllTextInPDF_byPage


"""
    Extract all the text data from the provided pdf file.
Open the pdf at the provided file location, extract all the text data from it (as
far as possible), and return that text data as a vector of strings.
Each entry in the rsult vector is the appended sum of some number of pages in the PDF.
100 Pages per entry is default. For example, the getAllTextInPDF(...)[0] will be a 
long string containing 100 pages worth of data. The next entry represents the next 100 
pages, etc.

Parameters
----------
fileLocation : The full path to the PDF file to open. This should be relative from where the
`julia` command has been run (not relative to this source file)

pagesPerEntry : How many pages should be collected into the buffere before turning it into
an entry in the result vector.
"""
function getAllTextInPDF(fileLocation::String, pagesPerEntry::Number=100)::Vector{String}
    result::Vector{String} = Vector{String}()
    buffer::IOBuffer = IOBuffer()
    pagesInBuffer::Number = 0

    # Open the pdf file
    pdfHandel::PDFIO.PD.PDDocImpl = PDFIO.pdDocOpen(fileLocation)

    # Loop over every page, extracting the text into the result buffer
    pageCount::Number = PDFIO.pdDocGetPageCount(pdfHandel)
    for currentPage::Number in range(1, pageCount)
        println("Working on page: " * string(currentPage) * " out of " * string(pageCount))
        try
            # The pdf file reader is a little flaky, so it'll 
            # produce AssertionErrors that the width of the page is too large :shrug:
            PDFIO.pdPageExtractText(buffer, pdDocGetPage(pdfHandel, currentPage))
            pagesInBuffer = pagesInBuffer + 1
        catch e
            println("Encountered error when trying to read page " * string(currentPage) * "\nSkipping page. Error:\n" * string(e))
            continue
        end

        if pagesInBuffer >= pagesPerEntry
            # Cash out the buffer into a String object and return.
            # WARNING: It may be a very large string object
            push!(result, bufferToString!(buffer))
            pagesInBuffer = 0
        end
    end
    # At the end cash out whatever's in the buffer
    push!(result, bufferToString!(buffer))
    return result
end # function getAllTextInPDF(fileLocation:string)

function getAllTextInPDF_byPage(fileLocation::String)::Vector{String}
    return getAllTextInPDF(fileLocation, 1)
end # function getAllTextInPDF_byPage(fileLocation::String)

"""
    Extract the contents of the buffer and convert it into a string object
WARNING: This function will clear out the contents of the buffer

Parameters
----------
buff : The buffer to clear, it's contents will be returned as a string
"""
function bufferToString!(buff::IOBuffer)
    return String(take!(buff))
end # function bufferToString!(...)

end # module PdfReader
