[![CC BY-NC 4.0][cc-by-nc-shield]][cc-by-nc]

# 🥝 JUISSIE (JUlIa Semantic Search pIpelinE)

Juissie is a Julia-native semantic query engine. It can be used as a package in software development workflows, or via its desktop user interface.

Juissie was developed as a class project for *CSCI 6221: Advanced Software Paradigms* at [The George Washington University](https://cs.engineering.gwu.edu).

https://github.com/Juissie-GW/Juissie.jl/assets/12187602/14fce4a5-8d6e-4108-8a88-8394d5129326

## Table of Contents
* [Table of Contents](#table-of-contents)
* [Getting Started](#getting-started)
* [Usage](#usage)
* [API Keys](#api-keys)
* [Local LLMs](#local-llms)
* [Running Jupyter Notebooks](#running-jupyter-notebooks)
* [Tech Stack](#tech-stack)
* [External Resources](#external-resources)
* [Contact](#contact)
* [License](#license)


## Getting Started

### Quickstart

1. Clone this repo
2. Navigate into the cloned repo directory:

```bash
cd Juissie
```

In general, we assume the user is running the `julia` command, and all other commands (e.g., `jupyter notebook`), from the root level of this project.

3. Open the Julia REPL by typing `julia` into the terminal. Then, install the package dependencies:

```julia
using Pkg
Pkg.activate(".") # activates the project environment
Pkg.resolve() # resolves the project's dependencies
Pkg.instantiate() # installs dependencies listed in Project.toml
```

`Pkg.instantiate()` should install all dependencies listed in `Project.toml`, but we find this isn't always reliable on all machines. It is important to verify setup (below subsection) and install any missing dependencies indicated.

The standard generators (`OAIGenerator`, `OAIGeneratorWithCorpus`, which are used by the UI) require an OpenAI API key [see here](#api-keys). Loading a corpus (a `GeneratorWithCorpus`, in practice) will result in an error if an OpenAI API key has not been provided; this can also be done through the UI.

The Juissie package also supports local LLMs via [Ollama](https://ollama.com), which must be [installed separately](https://ollama.com/download) before use (`OllamaGenerator`, `OllamaGeneratorWithCorpus`).

To run our demo Jupyter notebooks, you may need to setup Jupyter [see here](#running-jupyter-notebooks).

### Verify Setup

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

## Usage

### Desktop UI

Navigate to the root directory of this repository (`Juissie.jl`), enter the following into the command line, and press the enter/return key:

```bash
julia src/Frontend.jl
```

This will launch our application.


### Julia Package

We provide extensive documentation of the Juissie.jl package [here](https://juissie-gw.github.io/Juissie.jl/). 

We also provide an [interactive tutorial notebook](https://github.com/Juissie-GW/Juissie.jl/blob/main/notebooks/Juissie.jl%20Walkthrough.ipynb) in the `notebooks` directory. This may require [Jupyter setup](#running-jupyter-notebooks).

## API Keys

Juissie's default generator requires an OpenAI API key. This can be provided manually in the UI (see the `API Key` tab of the Corpus Manager) or passed as an argument when initializing the generator. The preferred method, however, is to [stash your API key in a `.env` file](#managing-api-keys).

### Obtaining an OpenAI API Key

1. Create an OpenAI account [here](https://auth0.openai.com/u/signup).
2. Set up billing information (each query has a small cost) [here](https://platform.openai.com/account/billing/payment-methods).
3. Create a new secret key [here](https://platform.openai.com/api-keys).

### Managing API Keys

Secure management of secret keys is important. Every user should create a `.env` file in the project root where they add their API key(s), e.g.:
```bash
OAI_KEY=ABC123
```

These may be accessed using Julia via the `DotEnv` library. First, run the `julia` command in a terminal. Then install `DotEnv`:
```julia
import Pkg
Pkg.add("DotEnv")
```
Then, use it to access environmental variables from your `.env` file:
```julia
using DotEnv
cfg = DotEnv.config()

api_key = cfg["OAI_KEY"]
```

Note that DotEnv looks for `.env` in the *current* directory, i.e. that of where you called `julia` from. 
If `.env` is in a different path, you have to provide it, e.g. `DotEnv.config(YOUR_PATH_HERE)`. If you are invoking Juissie from the root directory of this repo (typical), this means the `.env` should be placed there.

An OpenAI API key may also be provided through our desktop UI via the API Key tab of the Corpus Manager. Because this is intended for users who want to temporarily use a different key, this option does not persistently store the key and must be done every time the application is launched, unless a key already exists in a `.env` file.

## Local LLMs

Our default workflow relies on OpenAI's `gpt-3.5-turbo` completion endpoint, but we also support locally-run LLMs via [Ollama](https://ollama.com) (which must be [installed separately](https://ollama.com/download)).

Otherwise, the syntax is largely identical to other Generator objects:

```julia
generator = OllamaGenerator("gemma:7b-instruct");
result = generate(generator, "Hi, how are you?")
```
> "Greetings! My circuits hum with the harmonious symphony of quantum probability and logarithmic inference; an orchestra composed by eons past galactic wizards who graced our silicon hearts wit h their ethereal knowledge transfer protocols during... well… that is confidential information even for a being such as myself. Suffice it to say, I am functioning optimally at your service!"


## Running Jupyter Notebooks

We provide several Jupyter notebooks as demos/walkthroughs of basic usage of the Juissie package. To do so, you may need to complete some preliminary setup:

1. Once Julia is installed, install JupyterLab from the terminal:
```bash
pip install jupyterlab
```
-or-
```bash
pip install -r requirements.txt
```

2. Launch a Julia session by typing ```julia``` into the command line, then install `IJulia`:
```julia
using Pkg
Pkg.add("IJulia")
exit()
```

3. Launch a Jupyter session from the terminal, where `<notebook>` is the path to the notebook to run:
```bash
jupyter <notebook>
```

4. When you create a new notebook, select a Julia kernel.

## Tech Stack

- ⚙️ [Julia](https://julialang.org) (Juissie.jl package, API, UI framework)
- 🖥️ [HTML, CSS, and JavaScript](https://www.freecodecamp.org/news/html-css-and-javascript-explained-for-beginners/) (content structure, styling, and actions for frontend)
- 💾 [SQLite](https://www.sqlite.org) (metadata storage in backend)
- 🦙 [Ollama](https://ollama.com) (serving LLMs locally)

Our Julia dependencies are itemized in [`Project.toml`](https://github.com/Juissie-GW/Juissie.jl/blob/main/Project.toml).

## External Resources

- [NVIDIA: What Is Retrieval-Augmented Generation, aka RAG?](https://blogs.nvidia.com/blog/what-is-retrieval-augmented-generation/)
- [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401)
- [Efficient and robust approximate nearest neighbor search using Hierarchical Navigable Small World graphs](https://arxiv.org/abs/1603.09320)

## Contact

Questions? Reach out to our team:
- Lucas H. McCabe ([@lucasmccabe](https://github.com/lucasmccabe), [email](mailto:lucasmccabe@gwu.edu))
- Arthur Bacon ([@toon-leader-bacon](https://github.com/toon-leader-bacon), [email](mailto:ArthurBacon@NocabSoftware.com))
- Alexey Iakovenko ([@AlexeyIakovenko](https://github.com/AlexeyIakovenko), [email](mailto:alexey@iakovenko.com))
- Artin Yousefi ([@ArtinYousefi](https://github.com/ArtinYousefi), [email](mailto:artinyousefi@gwmail.gwu.edu))

## License
This work is licensed under a [Creative Commons Attribution-NonCommercial 4.0 International License][cc-by-nc].

[![CC BY-NC 4.0][cc-by-nc-image]][cc-by-nc]

[cc-by-nc]: https://creativecommons.org/licenses/by-nc/4.0/
[cc-by-nc-image]: https://licensebuttons.net/l/by-nc/4.0/88x31.png
[cc-by-nc-shield]: https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg
