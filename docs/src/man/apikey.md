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
cfg = DotEnv.config()

api_key = cfg["OAI_KEY"]
```

Note that DotEnv looks for `.env` in the *current* directory, i.e. that of the calling function. If `.env` is in a different path, you have to provide it, e.g. `DotEnv.config(YOUR_PATH_HERE)`


## Obtaining an OpenAI API Key

1. Create an OpenAI account [here](https://auth0.openai.com/u/signup).
2. Set up billing information (each query has a small cost) [here](https://platform.openai.com/account/billing/payment-methods).
3. Create a new sectet key [here](https://platform.openai.com/api-keys).