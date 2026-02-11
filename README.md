# Miiify

A lightweight, Git-backed web annotation server for IIIF applications using Irmin storage technology.

## Overview

Miiify provides persistent, structured access to web annotations through a read-only HTTP API.

- **Git backend** for annotation authoring and collaboration
- **Pack backend** for high-performance runtime queries

This separation enables Git-based workflows (pull requests, reviews, versioning) while maintaining fast, scalable annotation delivery.

## Architecture

### Storage Backends

**Git** - For development and collaboration:
- Standard Git operations (commit, push, pull, merge)
- Human-readable storage (JSON files)
- Version control and audit trails
- Pull request workflows for annotation review

**Pack** - For production runtime:
- Highly-compressed, disk-efficient storage
- Fast concurrent reads
- Based on Irmin Pack (used in Tezos blockchain)
- Compiled from Git for deployment

### Command Overview

```
miiify clone     Clone remote Git repository
miiify pull      Pull updates from remote repository
miiify import    Import JSON files into Git store (development)
miiify compile   Compile Git store to Pack store (deployment)
miiify serve     Run HTTP API server from Pack store
```

## Workflows

### Production Workflow

```bash
# 1. Clone annotation repository
miiify-clone https://github.com/org/annotations.git --git ./db

# 2. Update from remote (as needed)
miiify-pull --git ./db --remote origin --branch main

# 3. Compile to Pack for runtime
miiify-compile --git ./db --pack ./db-pack --validate

# 4. Run HTTP server
miiify-serve --repository ./db-pack --port 10000 --page-limit 200
```

### Development Workflow

```bash
# 1. Import local JSON files
miiify-import --input ./annotations --git ./db --validate

# 2. Compile to Pack
miiify-compile --git ./db --pack ./db-pack

# 3. Test locally
miiify-serve --repository ./db-pack --port 10000
```

### Collaborative Git Workflow

```bash
# Clone repository
git clone https://github.com/org/annotations.git

# Create annotations (standard JSON files)
cd annotations/my-container/collection/
echo '{"type":"Annotation",...}' > ann-001.json

# Commit and push
git add .
git commit -m "Add new annotations"
git push

# On server: pull, compile, restart
miiify-pull --git ./db
miiify-compile --git ./db --pack ./db-pack --validate
systemctl restart miiify
```

## Commands

### miiify-clone

Clone a remote Git repository containing annotations.

```bash
miiify-clone <repository-url> [OPTIONS]

Options:
  --git <dir>           Git store directory (default: db)
  --remote <name>       Remote name (default: origin)
  --branch <name>       Branch name (default: main)
```

**Example:**
```bash
miiify-clone https://github.com/org/annotations.git --git ./annotation-db
```

### miiify-pull

Pull updates from remote Git repository.

```bash
miiify-pull [OPTIONS]

Options:
  --git <dir>           Git store directory (default: db)
  --remote <name>       Remote name (default: origin)
  --branch <name>       Branch name (default: main)
```

**Example:**
```bash
miiify-pull --git ./db --branch production
```

### miiify-import

Import JSON annotation files into Git store (development tool).

```bash
miiify-import [OPTIONS]

Options:
  --input <dir>         Directory containing JSON files (default: db)
  --git <dir>           Git store directory (default: db)
  --validate            Validate annotations during import
```

**File structure expected:**
```
annotations/
├── container-1/
│   ├── main.json              # Container metadata
│   └── collection/
│       ├── ann-001.json       # Annotation files
│       ├── ann-002.json
│       └── ...
└── container-2/
    ├── main.json
    └── collection/
        └── ...
```

**Example:**
```bash
miiify-import --input ./my-annotations --git ./db --validate
```

### miiify-compile

Compile Git store to Pack store for production deployment.

```bash
miiify-compile [OPTIONS]

Options:
  --git <dir>           Git store directory (default: db)
  --pack <dir>          Pack store directory (default: db-pack)
  --validate            Validate annotations during compilation
```

**Example:**
```bash
miiify-compile --git ./annotation-db --pack ./prod-db --validate
```

### miiify-serve

Run HTTP API server from Pack store (read-only).

```bash
miiify-serve [OPTIONS]

Options:
  --repository <dir>    Pack store directory (default: db)
  --port <number>       Server port (default: 10000)
  --page-limit <number> Maximum items per page (default: 200)
```

**Example:**
```bash
miiify-serve --repository ./db-pack --port 8080 --page-limit 100
```

## HTTP API

The server provides a read-only HTTP API for retrieving annotations.

### Endpoints

**Status Check**
```bash
GET /
GET /version
```

**Get Container**
```bash
GET /annotations/:container_id
```

**Get Annotation Page**
```bash
GET /annotations/:container_id/?page=0
GET /annotations/:container_id/?page=0&target=<uri>
```

**Get Single Annotation**
```bash
GET /annotations/:container_id/:annotation_id
```

### Examples

Using [httpie](https://httpie.io/):

```bash
# Check server status
http localhost:10000/

# Get container metadata
http localhost:10000/annotations/my-container

# Get first page of annotations
http localhost:10000/annotations/my-container/?page=0

# Filter annotations by target
http localhost:10000/annotations/my-container/?page=0&target=https://example.com/canvas1

# Get specific annotation
http localhost:10000/annotations/my-container/ann-001
```

### Response Format

**Annotation Page:**
```json
{
  "@context": "http://iiif.io/api/presentation/3/context.json",
  "id": "http://localhost:10000/annotations/my-container/?page=0",
  "type": "AnnotationPage",
  "startIndex": 0,
  "items": [
    {
      "@context": "http://www.w3.org/ns/anno.jsonld",
      "id": "http://localhost:10000/annotations/my-container/ann-001",
      "type": "Annotation",
      "body": { ... },
      "target": "https://example.com/canvas1",
      "created": "2024-01-15T10:30:00Z"
    }
  ],
  "partOf": {
    "id": "http://localhost:10000/annotations/my-container/",
    "type": "AnnotationCollection",
    "label": "My Annotations",
    "total": 42,
    "created": "2024-01-15T09:00:00Z"
  }
}
```

## Validation

Optional ATD-based validation during import and compilation using [ATDgen](https://atd.readthedocs.io/).

**Enable validation:**
```bash
miiify-import --input ./annotations --git ./db --validate
miiify-compile --git ./db --pack ./db-pack --validate
```

**Custom specification:**
Place `specification.atd` in your annotation directory. See [example specification](https://raw.githubusercontent.com/jptmoore/maniiifest/main/src/specification.atd).

