# julia-notebooks
Brief notes on using Julia in a Jupyter Notebook.

1. Once Julia is installed, install JupyterLab from the terminal:
```bash
pip install jupyterlab
```
2. Launch a Julia session by typing ```julia``` into the command line, then install `IJulia`:
```julia
using Pkg
Pkg.add("IJulia")
```
3. Launch a Jupyter session from the terminal:
```bash
jupyter notebook
```
4. When you create a new notebook, select a Julia kernel.