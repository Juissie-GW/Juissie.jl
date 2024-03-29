push!(LOAD_PATH,"../src/")

using Documenter, Juissie

makedocs(
    format = Documenter.HTML(),
    modules = [Juissie],
    sitename = "Juissie.jl",
    authors = "Lucas H. McCabe, Arthur Bacon, Alexey Iakovenko, Artin Yousefi",
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "man/guide.md",
            "man/apikey.md",
        ]
    ],
)

deploydocs(
    repo = "github.com/JuliaDocs/Juissie.jl.git",
    target = "build",
    deps = nothing,
    make = nothing,
)