# Miiify

**Web annotations versioned like code, served like a database.**

Setup and deployment: start with [doc/installation.md](doc/installation.md).

Miiify treats annotations like source code: store them in Git, serve them from an optimized runtime.

Your annotations evolve like a codebase. Anyone who already uses Git can contribute using the same workflow: commit, review, merge. No database setup, no config files, just JSON files and Git.

## Quick Start

Create annotations as JSON files and serve them via HTTP API.

### Create Annotation Files

**Using an existing Git repository?** Use `miiify-clone` to get started with [sample annotation data](https://github.com/jptmoore/miiify-sample-data):
```bash
miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./db-git
```

**Or create annotations manually:**

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

### Import

If you created annotations manually, import them into Git storage:

```bash
miiify-import --input ./annotations --git ./db-git
```


### Compile

Compile Git storage to Pack storage for serving:

```bash
miiify-compile --git ./db-git --pack ./db-pack
```

### Run Server

```bash
# Start the HTTP API server
miiify-serve --repository ./db-pack --port 10000
```

### Access Annotations

```bash
# Get annotation
curl http://localhost:10000/my-canvas/highlight-1

# List all annotations (AnnotationCollection)
curl http://localhost:10000/my-canvas/

# Get specific page (AnnotationPage)
curl http://localhost:10000/my-canvas/?page=0
```

## ID Management

Miiify injects stable, URL-based annotation `id` fields at serve time—you never include IDs in your JSON files.

These IDs are plain HTTP URLs derived from `--base-url` and the request path (suitable for use as Web Annotation identifiers).


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

## Scaling

See [doc/scaling.md](doc/scaling.md) for horizontal scaling strategies from single projects to institution-wide deployments serving millions of annotations.
