# Installation

Miiify can be installed using Docker or natively on Linux/macOS.

## Docker (Recommended)

The easiest way to get started is with Docker, which includes all dependencies and commands.

### Build the Docker image

```bash
# Clone the repository
git clone https://github.com/nationalarchives/miiify.git
cd miiify

# Build the Docker image
docker build -t miiify .
```

### Using Docker commands

All Miiify commands are available in the Docker image. You can run them using `docker run`:

```bash
# Clone a repository (recommended)
docker run --rm -v $(pwd)/git_store:/home/miiify/git_store miiify \
  /home/miiify/miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./git_store

# OR: Import local annotations from filesystem (if you created files manually)
docker run --rm -v $(pwd)/annotations:/home/miiify/annotations -v $(pwd)/git_store:/home/miiify/git_store miiify \
  /home/miiify/miiify-import --input ./annotations --git ./git_store

# Compile to pack store (required after clone or import)
docker run --rm -v $(pwd)/git_store:/home/miiify/git_store -v $(pwd)/pack_store:/home/miiify/pack_store miiify \
  /home/miiify/miiify-compile --git ./git_store --pack ./pack_store

# Serve annotations
docker run --rm -p 10000:10000 -v $(pwd)/pack_store:/home/miiify/pack_store miiify \
  --repository ./pack_store --port 10000 --base-url http://localhost:10000
```

### Using Docker Compose

For production deployments, use Docker Compose:

```bash
# Start the server (default configuration)
docker compose up -d

# View logs
docker compose logs -f

# Stop the server
docker compose down

# Run other commands using docker compose run
docker compose run --rm miiify /home/miiify/miiify-compile --git ./git_store --pack ./pack_store
```

Environment variables can be configured in a `.env` file:
```bash
MIIIFY_PORT=10000              # Host port (container always uses 10000 internally)
MIIIFY_REPOSITORY=pack_store
MIIIFY_PAGE_LIMIT=200
MIIIFY_BASE_URL=http://localhost:10000
```

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

