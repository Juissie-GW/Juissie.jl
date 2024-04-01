# Setup

1. Clone this repo
2. Navigate into the cloned repo directory:

```bash
cd Juissie
```

In general, we assume the user is running the `julia` command, and all other commands (e.g., `jupyter notebook`), from the root level of this project.

3. Open the Julia REPL by typing `julia` into the terminal. Then, install the package dependencies:

```julia
using Pkg
Pkg.activate(".")
Pkg.resolve()
Pkg.instantiate()
```

# Verify Setup

1. From this repo's home directory, open the Julia REPL by typing `julia` into the terminal. Then, try importing the Juissie module:

```julia
using Juissie
```

This should expose symbols like `Corpus`, `Embedder`, `upsert_chunk`, `upsert_document`, `search`, and `embed`.

2. Try instantiating one of the exported struct, like `Corpus`:

```julia
corpus = Corpus()
```

We can test the `upsert` and search functionality associated with `Corpus` like so:

```julia
upsert_chunk(corpus, "Hold me closer, tiny dancer.", "doc1")
upsert_chunk(corpus, "Count the headlights on the highway.", "doc1")
upsert_chunk(corpus, "Lay me down in sheets of linen.", "doc2")
upsert_chunk(corpus, "Peter Piper picked a peck of pickled peppers. A peck of pickled peppers, Peter Piper picked.", "doc2")
```

Search those chunks:

```julia
idx_list, doc_names, chunks, distances = search(
    corpus, 
    "tiny dancer", 
    2
)
```

The output should look like this:

```bash
([1, 3], ["doc1", "doc2"], ["Hold me closer, tiny dancer.", "Lay me down in sheets of linen."], Vector{Float32}[[5.198073, 9.5337925]])
```
