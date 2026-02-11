# Miiify

**Web annotations versioned like code, served like a database.**

Traditional annotation servers require databases, complex configuration, and specialized deployment. They separate your annotations from your content workflows.

Miiify solves this by treating annotations like source code: store them in Git, serve them from an optimized runtime.

Your annotations evolve like a codebase. IIIF scholars and content specialists who already use Git for documentation can contribute annotations using the same workflow—commit, review, merge. No database setup, no config files, just JSON files and Git.

Miiify uses the same storage technology that powers the Tezos blockchain (Irmin), giving your annotations blockchain-grade immutability and integrity. Deploy across multiple locations for digital preservation—each location independently compiles from Git to create verifiable identical copies.

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
curl http://localhost:10000/my-canvas/highlight-1.json

# List all annotations
curl http://localhost:10000/my-canvas/
```

**Using an existing Git repository?** Use `miiify-clone` instead of creating files manually:
```bash
miiify-clone https://github.com/org/annotations.git --git ./db-git
miiify-compile --git ./db-git --pack ./db-pack
miiify-serve --repository ./db-pack --port 10000
```

## ID Management

Miiify automatically generates W3C-compliant annotation IDs at runtime—you never include IDs in your JSON files.

**How it works:**
- IDs are derived from your filesystem structure: `<base-url>/<container>/<slug>`
- Container = directory name (e.g., `my-canvas`)
- Slug = filename without `.json` extension (e.g., `highlight-1`)
- Base URL is configurable via `--base-url` flag

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

### miiify-clone

Clone a remote Git repository into Irmin Git store.

```bash
miiify-clone <repo-url> [OPTIONS]

Arguments:
  <repo-url>            Remote Git repository URL

Options:
  --git <dir>           Git store directory (default: db)
```

**Example:**
```bash
miiify-clone https://github.com/org/annotations.git --git ./db-git
```

### miiify-pull

Pull updates from remote and merge into Irmin Git store.

```bash
miiify-pull [OPTIONS]

Options:
  --git <dir>           Git store directory (default: db)
  --remote <name>       Remote name (default: origin)
  --branch <name>       Branch name (default: main)
```

**Example:**
```bash
miiify-pull --git ./db-git
miiify-pull --remote upstream --branch develop --git ./db-git
```

### miiify-import

Import JSON annotation files into Git store.

```bash
miiify-import [OPTIONS]

Options:
  --input <dir>         Directory containing JSON files (default: ./annotations)
  --git <dir>           Git store directory (default: db-git)
```

**Example:**
```bash
miiify-import --input ./annotations --git ./db-git
```

### miiify-compile

Compile Git store to Pack store for serving.

```bash
miiify-compile [OPTIONS]

Options:
  --git <dir>           Git store directory (default: db-git)
  --pack <dir>          Pack store directory (default: db-pack)
```

**Example:**
```bash
miiify-compile --git ./db-git --pack ./db-pack
```

### miiify-serve

Run HTTP API server from Pack store.

```bash
miiify-serve [OPTIONS]

Options:
  --repository <dir>    Pack store directory (default: db-pack)
  --port <number>       Server port (default: 10000)
  --page-limit <number> Maximum items per page (default: 200)
  --base-url <url>      Base URL for annotation IDs (default: http://localhost:10000)
```

**Example:**
```bash
miiify-serve --repository ./db-pack --port 8080 --base-url https://example.com
```

## HTTP API

The server provides a read-only HTTP API for retrieving annotations.

### URL Structure

Annotations use a simple `/<container>/<slug>` URL pattern:
- **Container**: Directory name (e.g., `my-canvas`, `page-42`)
- **Slug**: Filename without `.json` extension (e.g., `highlight-1`, `comment-3`)
- Both formats work: `/<container>/<slug>` and `/<container>/<slug>.json`

### Endpoints

```
GET /                          # Server status
GET /version                   # Version info
GET /:container                # Get container metadata (AnnotationContainer)
GET /:container/               # Get collection with first page (AnnotationCollection)
GET /:container/?page=N        # Get specific page (AnnotationPage)
GET /:container/:slug          # Get specific annotation
```

### Examples

```bash
# Get annotation (both work)
curl http://localhost:10000/my-canvas/highlight-1
curl http://localhost:10000/my-canvas/highlight-1.json

# Get collection with first page embedded
curl http://localhost:10000/my-canvas/

# Get specific page
curl http://localhost:10000/my-canvas/?page=0
curl http://localhost:10000/my-canvas/?page=1

# Filter by target
curl "http://localhost:10000/my-canvas/?page=0&target=https://example.com/iiif/canvas/1"
```

### Response Format

**Single Annotation:**
```json
{
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "id": "http://localhost:10000/my-canvas/highlight-1",
  "type": "Annotation",
  "motivation": "highlighting",
  "body": {
    "type": "TextualBody",
    "value": "Important passage",
    "purpose": "commenting"
  },
  "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50",
  "created": "2024-01-15T10:30:00Z"
}
```

**Annotation Page:**
```json
{
  "@context": "http://iiif.io/api/presentation/3/context.json",
  "id": "http://localhost:10000/my-canvas/?page=0",
  "type": "AnnotationPage",
  "items": [
    {
      "@context": "http://www.w3.org/ns/anno.jsonld",
      "id": "http://localhost:10000/my-canvas/highlight-1",
      "type": "Annotation",
      "body": { ... },
      "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50",
      "created": "2024-01-15T10:30:00Z"
    }
  ],
  "partOf": {
    "id": "http://localhost:10000/my-canvas/",
    "type": "AnnotationCollection",
    "label": "My Annotations",
    "total": 42,
    "created": "2024-01-15T09:00:00Z"
  }
}
```
