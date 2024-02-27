
module PdfReader

using PDFIO

export getAllTextInPDF, getPagesInPDF_All

"""
    Extract all the text data from the provided pdf file.
Open the pdf at the provided file location, extract all the text data from it (as
far as possible), and return that text data as a vector of strings.
Each entry in the rsult vector is the appended sum of some number of pages in the PDF.
100 Pages per entry is default. For example, the getAllTextInPDF(...)[0] will be a 
long string containing 100 pages worth of data. The next entry represents the next 100 
pages, etc.

NOTE: This function is a "best effort" function, meaning that it will try to extract as
many pages as it can. But if there are pages that are invalid, or otherwise can not
be properly parsed then they will simply be ignored and not included in the 
returned strings.

Parameters
----------
fileLocation : The full path to the PDF file to open. This should be relative from where the
`julia` command has been run (not relative to this source file)

pagesPerEntry : How many pages should be collected into the buffere before turning it into
an entry in the result vector.
"""
function getAllTextInPDF(fileLocation::String, pagesPerEntry::Number=100)::Vector{String}
    result::Vector{String} = Vector{String}()

    # Open the pdf file
    pdfHandel::PDFIO.PD.PDDocImpl = PDFIO.pdDocOpen(fileLocation)
    pageCount::Number = PDFIO.pdDocGetPageCount(pdfHandel)
    # Grab chunks of the target PDF and push them onto the result
    for chunkStartPage::Number in range(start=1, stop=pageCount, step=pagesPerEntry)
        chunkEndPage = chunkStartPage + pagesPerEntry
        chunkStartPage = chunkStartPage + 1 # Avoids double counting of the page
        push!(result, getPagesFromPdf(pdfHandel, chunkStartPage, chunkEndPage))
    end

    return result
end # function getAllTextInPDF(fileLocation:string)

"""
    Collect and return all the text data found in the pdf file found in the provided page range.

Using the provided file path, open the PDF and loop over all the pages in the range and attempt to extract
the text data. All the collected data will be returned.

The specific pages to read are defined by [firstPageInclusive, lastPageInclusive] which (naturally)
defines an inclusive range. Meaning the first and last page number will be included in the returned
string. These ranges SHOULD be valid (ie, in the range [1, MaxPageCount]) but error checking will
coerce the values to a proper range.


Parameters
----------
fileLocation : The location of the PDF to read
firstPageInclusive : The first page in the range to read
lastPageInclusive : The last page in the range to read
"""
function getPagesFromPdf(fileLocation::String, firstPageInclusive::Number, lastPageInclusive::Number)::String
    # Open the pdf file
    pdfHandel::PDFIO.PD.PDDocImpl = PDFIO.pdDocOpen(fileLocation)
    return getPagesFromPdf(pdfHandel, firstPageInclusive, lastPageInclusive)
end # function getPagesFromPdf()

"""
    Collect and return all the text data found in the pdf file found in the provided page range.

Using the provided PDF Handel, loop over all the pages in the range and attempt to extract
the text data. All the collected data will be returned.

The specific pages to read are defined by [firstPageInclusive, lastPageInclusive] which (naturally)
defines an inclusive range. Meaning the first and last page number will be included in the returned
string. These ranges SHOULD be valid (ie, in the range [1, MaxPageCount]) but error checking will
coerce the values to a proper range.


Parameters
----------
pdfHandel : The PDF file to extract data from
firstPageInclusive : The first page in the range to read
lastPageInclusive : The last page in the range to read
"""
function getPagesFromPdf(pdfHandel::PDFIO.PD.PDDocImpl, firstPageInclusive::Number, lastPageInclusive::Number)::String
    result::IOBuffer = IOBuffer()

    # Error checking on the bounds
    firstPageInclusive = max(1, firstPageInclusive)
    lastPageInclusive = min(lastPageInclusive, PDFIO.pdDocGetPageCount(pdfHandel))
    # Flip the min and max if needed
    firstPageInclusive = min(firstPageInclusive, lastPageInclusive)
    lastPageInclusive = max(firstPageInclusive, lastPageInclusive)

    # Loop over every page in the range, extracting the text into the result buffer
    for currentPage::Number in range(firstPageInclusive, lastPageInclusive)
        try
            # The pdf file reader is a little flaky, so it'll 
            # produce AssertionErrors that the width of the page is too large :shrug:
            PDFIO.pdPageExtractText(result, pdDocGetPage(pdfHandel, currentPage))
        catch e
            println("Encountered error when trying to read page " * string(currentPage) * "\nSkipping page. Error:\n" * string(e))
            continue
        end
    end # end loop over pages
    # At the end cash out whatever's in the buffer
    return bufferToString!(result)
end # function getPagesFromPdf()

"""
    Extract all the text data from the provided pdf file.
Open the pdf at the provided file location, extract all the text data from it (as
far as possible), and return that text data as a vector of strings.
Each entry in the result vector is the data from a single page of the PDF file.

NOTE: This function is a "best effort" function, meaning that it will try to extract as
many pages as it can. But if there are pages that are invalid, or otherwise can not
be properly parsed then they will simply be ignored and not included in the 
returned strings.

Parameters
----------
fileLocation : The full path to the PDF file to open. This should be relative from where the
`julia` command has been run (not relative to this source file)
"""
function getPagesInPDF_All(fileLocation::String)::Vector{String}
    return getAllTextInPDF(fileLocation, 1)
end # function getPagesInPDF_All(fileLocation::String)

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
