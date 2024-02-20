# Managing API-Keys

Secure management of secret keys is important. Every user should create a `.env` file in the project root where they add their API key(s), e.g.:
```bash
OAI_KEY=ABC123
```

These may be accessed using Julia via the `DotEnv` library. First, install `DotEnv`:
```julia
import Pkg
Pkg.add("DotEnv")
```
Then, use it to access environmental variables from your `.env` file:
```julia
using DotEnv
DotEnv.config()

api_key = ENV["OAI_KEY"]
```

Note that DotEnv looks for `.env` in the *current* directory, i.e. that of the calling function. If `.env` is in a different path, you have to provide it, e.g. `DotEnv.config(YOUR_PATH_HERE)`