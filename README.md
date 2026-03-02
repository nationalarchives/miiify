# Miiify

**Web annotations versioned like code, served like a database.**

Setup and deployment: start with [doc/installation.md](doc/installation.md).

Store annotations in Git, serve them from an optimized read-only store. Use familiar version control workflows without any database setup.

## Key Features

- **Git-based workflow**: Familiar version control for annotations
- **No database required**: Just files and Git
- **Optimized serving**: Read-optimized store for fast, efficient HTTP API
- **Stable IDs**: Generated at serve-time from filesystem structure
- **Horizontal scaling**: Serve millions of annotations across multiple instances
- **Separation of concerns**: Storage/serving decoupled from search

## Quick Start

### 1. Get Annotation Data

**Option A: Clone from Git** (recommended)

Use `miiify-clone` to get started with [sample annotation data](https://github.com/jptmoore/miiify-sample-data):

```bash
miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./git_store
```

<details>
<summary><strong>Using Docker?</strong> Click to see Docker commands</summary>

```bash
# Clone using Docker
docker run --rm -v $(pwd)/git_store:/home/miiify/git_store miiify \
  /home/miiify/miiify-clone https://github.com/jptmoore/miiify-sample-data.git --git ./git_store
```

</details>

**Option B: Create from filesystem**

Create annotation files manually:

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

Then import them into Git storage:

```bash
miiify-import --input ./annotations --git ./git_store
```

<details>
<summary><strong>Using Docker?</strong> Click to see Docker commands</summary>

```bash
# Import using Docker
docker run --rm \
  -v $(pwd)/annotations:/home/miiify/annotations \
  -v $(pwd)/git_store:/home/miiify/git_store miiify \
  /home/miiify/miiify-import --input ./annotations --git ./git_store
```

</details>

### 2. Compile to Pack Store

Compile Git storage to optimized pack storage for serving (required for both options):

```bash
miiify-compile --git ./git_store --pack ./pack_store
```

<details>
<summary><strong>Using Docker?</strong> Click to see Docker commands</summary>

```bash
# Compile using Docker
docker run --rm \
  -v $(pwd)/git_store:/home/miiify/git_store \
  -v $(pwd)/pack_store:/home/miiify/pack_store miiify \
  /home/miiify/miiify-compile --git ./git_store --pack ./pack_store
```

</details>

### 3. Run Server

```bash
# Start the HTTP API server
miiify-serve --repository ./pack_store --port 10000
```

<details>
<summary><strong>Using Docker?</strong> Click to see Docker commands</summary>

```bash
# Serve using Docker
docker run --rm -p 10000:10000 \
  -v $(pwd)/pack_store:/home/miiify/pack_store miiify \
  --repository ./pack_store --port 10000 --base-url http://localhost:10000

# Or use Docker Compose
docker compose up -d
```

</details>

### 4. Access Annotations

```bash
# Get annotation
curl http://localhost:10000/my-canvas/highlight-1

# List all annotations (AnnotationCollection)
curl http://localhost:10000/my-canvas/

# Get specific page (AnnotationPage)
curl http://localhost:10000/my-canvas/?page=0
```

## ID Management

Miiify injects stable, URL-based annotation `id` fields at serve time. IDs are derived from filesystem structure and deployment configuration—never stored in your JSON files.

**How it works:**
- IDs follow the pattern: `<base-url>/<container>/<slug>`
- Container = directory name (e.g., `my-canvas`)
- Slug = filename without `.json` extension (e.g., `highlight-1`)
- Base URL is configurable via `--base-url` flag

**Example:**
```bash
# Your file: annotations/my-canvas/highlight-1.json
# Served with ID: "http://localhost:10000/my-canvas/highlight-1"
```

**Deployment flexibility:**
```bash
# Development
miiify-serve --base-url http://localhost:10000

# Production
miiify-serve --base-url https://annotations.example.org
```

Same JSON files, different IDs based on deployment. No database updates, no file edits—just change the flag.

## Search

Miiify implements a separation of concerns: it provides storage and serving infrastructure, while search functionality is delegated to solutions such as [annosearch](https://github.com/nationalarchives/annosearch). This architectural decision enables annotations to be organized by canvas but indexed at IIIF Collection level. Storage and search strategies evolve independently.

## HTTP API

See [doc/api.md](doc/api.md) for the full HTTP API reference.

## Scaling

See [doc/scaling.md](doc/scaling.md) for horizontal scaling strategies from single projects to institution-wide deployments serving millions of annotations.

## Commands

See [doc/commands.md](doc/commands.md) for the full command reference.
