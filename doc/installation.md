# Installation

## Linux (Ubuntu/Debian)

```bash
# Install OCaml and opam
sudo apt-get update
sudo apt-get install -y opam libgmp-dev libev-dev libssl-dev pkg-config

# Initialize opam (if not already done)
opam init -y
eval $(opam env)

# Install OCaml 5.4.0 (or later)
opam switch create 5.4.0
eval $(opam env)

# Clone and build Miiify
git clone https://github.com/nationalarchives/miiify.git
cd miiify/miiify
opam install . --deps-only --with-test -y
dune build --release

# Install binaries to ~/.local/bin or /usr/local/bin
dune install
```

## macOS

```bash
# Install dependencies via Homebrew
brew install opam gmp libev openssl pkg-config

# Then follow the same opam/dune steps as Linux above
opam init -y
eval $(opam env)
opam switch create 5.4.0
eval $(opam env)

# Clone and build Miiify
git clone https://github.com/nationalarchives/miiify.git
cd miiify/miiify
opam install . --deps-only --with-test -y
dune build --release

# Install binaries
dune install
```

## Available Binaries

After installation, the following binaries will be available:
- `miiify-clone` - Clone a Git repository of annotations
- `miiify-pull` - Pull updates from remote Git
- `miiify-push` - Push local changes to remote Git
- `miiify-import` - Import local JSON annotation files (dev/testing)
- `miiify-compile` - Compile Git store to optimized Pack format
- `miiify-serve` - Start HTTP annotation server

Note: `miiify-import --validate` / `miiify-compile --validate` enables strict schema validation and may reject JSON that is otherwise acceptable for serving. If you hit validation errors, retry without `--validate`.

## Troubleshooting

**opam not found:**
- Make sure you've run `eval $(opam env)` after installing opam

**Build fails with missing dependencies:**
- Ensure all system dependencies are installed: `libgmp-dev libev-dev libssl-dev pkg-config`

**Permission errors during install:**
- Use `dune install --prefix ~/.local` to install to your home directory
- Or use `sudo dune install` to install system-wide

