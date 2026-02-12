# Miiify

**Web annotations versioned like code, served like a database.**

Setup and deployment: start with [doc/installation.md](doc/installation.md).

Traditional annotation servers require databases, complex configuration, and specialized deployment. They separate your annotations from your content workflows.

Miiify solves this by treating annotations like source code: store them in Git, serve them from an optimized runtime.

Your annotations evolve like a codebase. Anyone who already uses Git can contribute using the same workflow—commit, review, merge. No database setup, no config files, just JSON files and Git.

## Quick Start

Create annotations as JSON files and serve them via HTTP API.

### 1. Create Annotation Files

```bash
# Create directory structure
mkdir -p annotations/my-canvas

# Create an annotation
cat > annotations/my-canvas/highlight-1.json << 'EOF'
{
  "type": "Annotation",
  "motivation": "highlighting",
  "body": {
    "type": "TextualBody",
    "value": "Important passage",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50"
}
EOF

# Create another annotation
cat > annotations/my-canvas/comment-1.json << 'EOF'
{
  "type": "Annotation",
  "motivation": "commenting",
  "body": {
    "type": "TextualBody",
    "value": "This is a fascinating detail",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=300,150,100,75"
}
EOF
```

### 2. Import and Compile

```bash
# Import JSON files into Git storage
miiify-import --input ./annotations --git ./db-git

# Compile to Pack storage for serving
miiify-compile --git ./db-git --pack ./db-pack
```

### 3. Run Server

```bash
# Start the HTTP API server
miiify-serve --repository ./db-pack --port 10000
```

### 4. Access Annotations

```bash
# Get annotation (both formats work)
curl http://localhost:10000/my-canvas/highlight-1

# List all annotations
curl http://localhost:10000/my-canvas/
```

**Using an existing Git repository?** Use `miiify-clone` instead of creating files manually:
```bash
miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./db-git
miiify-compile --git ./db-git --pack ./db-pack
miiify-serve --repository ./db-pack --port 10000
```

## ID Management

Miiify injects stable, URL-based annotation `id` fields at serve time—you never include IDs in your JSON files.

These IDs are plain HTTP URLs derived from `--base-url` and the request path (suitable for use as Web Annotation identifiers).

If an annotation file supplies a top-level `id`, `miiify-import`/`miiify-compile` will error: the server owns the `id` value.

**How it works:**
- IDs are derived from your filesystem structure: `<base-url>/<container>/<slug>`
- Container = directory name (e.g., `my-canvas`)
- Slug = filename without `.json` extension (e.g., `highlight-1`)
- Base URL is configurable via `--base-url` flag

**Ordering:**
- When listing annotations (collection/pages), items are returned sorted lexicographically by slug/ID.
- If you care about a specific order within a canvas/container, choose slugs accordingly (for example, zero-pad: `note-0001`, `note-0010` so `note-0010` doesn’t sort before `note-0002`).

**Example:**
```bash
# Your file: annotations/my-canvas/highlight-1.json
# Served as: http://localhost:10000/my-canvas/highlight-1
# With ID: "id": "http://localhost:10000/my-canvas/highlight-1"
```

**Deployment flexibility:**
```bash
# Development
miiify-serve --base-url http://localhost:10000

# Production
miiify-serve --base-url https://annotations.example.org
```

Same JSON files, different IDs based on deployment. No database updates, no file edits—just change the flag.

## Commands

See [doc/commands.md](doc/commands.md) for the full command reference.

## HTTP API

See [doc/api.md](doc/api.md) for the full HTTP API reference.
