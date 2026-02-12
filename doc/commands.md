# Commands

This page contains a detailed reference for Miiify’s CLI tools.

For a minimal “clone → compile → serve” walkthrough using sample data, see the Quick Start in [README.md](../README.md).

## miiify-clone

Clone a remote Git repository into an Irmin Git store.

```bash
miiify-clone <repo-url> [OPTIONS]

Arguments:
  <repo-url>            Remote Git repository URL

Options:
  --git <dir>           Git store directory (default: db)
  --force               Allow cloning into an existing non-empty --git directory
```

Example:
```bash
miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./db-git
```

Notes:
- By default, `miiify-clone` refuses to clone into an existing non-empty `--git` directory.
- Use `--force` to reuse an existing store (this may move the store’s HEAD to the remote head).

## miiify-pull

Pull updates from a remote and merge into an Irmin Git store.

```bash
miiify-pull <repo-url> [OPTIONS]

Arguments:
  <repo-url>            Remote Git repository URL

Options:
  --git <dir>           Git store directory (default: db)
  --branch <name>       Branch name (default: main)
```

Example:
```bash
miiify-pull https://github.com/jptmoore/miiify-sample-data.git --git ./db-git
```

Note: Use HTTPS URLs. SSH URLs (`git@github.com:...`) are not currently supported.

## miiify-push

Push local changes to a remote Git repository.

```bash
miiify-push <repo-url> [OPTIONS]

Arguments:
  <repo-url>            Remote Git repository URL

Options:
  --git <dir>           Git store directory (default: db)
  --branch <name>       Branch name (default: main)
```

Example:
```bash
# For public repos with GitHub token
miiify-push https://TOKEN@github.com/org/annotations.git --git ./db-git

# Or use manual git push
cd ./db-git
git remote add origin https://github.com/org/annotations.git
git push origin main
```

Note: Push requires authentication. Use HTTPS URLs with a GitHub Personal Access Token, or use manual `git push`. SSH URLs are not currently supported.

## miiify-import

Import annotation files from a directory into an Irmin Git store (development tool).

Annotation files may be either:
- `*.json`, or
- extensionless files (no `.` in the filename)

```bash
miiify-import [OPTIONS]

Options:
  --input <dir>         Input directory containing container directories (default: ./annotations)
  --git <dir>           Git store directory (default: db)
  --validate            Validate JSON against specification.atd schema before importing
```

Example:
```bash
miiify-import --input ./annotations --git ./db-git --validate
```

## miiify-compile

Compile a Git store into an optimized Pack store for serving.

```bash
miiify-compile [OPTIONS]

Options:
  --git <dir>           Source Git store directory (default: db)
  --pack <dir>          Destination Pack store directory (default: db-pack)
  --validate            Enable strict schema validation against specification.atd
```

Example:
```bash
miiify-compile --git ./db-git --pack ./db-pack --validate
```

## miiify-serve

Run the HTTP API server from a Pack store.

```bash
miiify-serve [OPTIONS]

Options:
  --repository <dir>    Pack store directory (default: db-pack)
  --port <number>       Server port (default: 10000)
  --page-limit <number> Maximum items per page (default: 200)
  --base-url <url>      Base URL for annotation IDs (default: http://localhost:10000)
```

Example:
```bash
miiify-serve --repository ./db-pack --port 8080 --base-url https://example.com
```
