# Scaling Miiify

This document explains how to scale Miiify from a single project to institution-wide deployment serving millions of annotations.

**Note:** In this document, "container" refers to an annotation container (a collection of annotations as defined in the [W3C Web Annotation Data Model](https://www.w3.org/TR/annotation-model/#collections)), not Docker containers.

## Horizontal Scaling

Miiify's read-only architecture enables simple horizontal scaling to millions of annotations - run multiple independent instances and route container requests to the appropriate deployment.

**Resource efficiency:** Miiify is very lightweight. The Pack store is highly compressed and optimized for read performance, with minimal CPU and memory requirements at runtime. This makes it practical to run many instances or dedicate machines to individual large projects.

## Repository Organization

### Strategy: Hybrid Deployment

Use a hybrid approach based on project size and update frequency:

- **Large projects** (e.g., Domesday Book with 400+ canvases): One repository per project, deployed to its own machine
- **Small/medium projects**: Group by category into shared repositories on shared machines

**Why this works:**
- Large projects benefit from isolated resources, independent updates, and faster compile times
- Grouping small projects is cost-efficient and reduces operational overhead
- Miiify's lightweight footprint makes dedicated machines practical for major projects

**Example structure:**
```
# Large project - dedicated machine
domesday-book/                             (repo → dedicated machine)
├── domesday-book-folio-001-recto/        (container = canvas)
│   ├── annotation-1.json
│   ├── annotation-2.json
│   └── annotation-3.json
├── domesday-book-folio-001-verso/        (container = canvas)
│   ├── annotation-1.json
│   └── annotation-2.json
└── domesday-book-folio-002-recto/        (container = canvas)
    └── annotation-1.json

# Grouped small/medium projects - shared machine
medieval-annotations/                      (repo → shared machine)
├── magna-carta-clause-1/                 (container = canvas)
│   ├── annotation-1.json
│   └── annotation-2.json
├── magna-carta-clause-39/                (container = canvas)
│   └── annotation-1.json
└── bayeux-tapestry-scene-001/            (container = canvas)
    ├── annotation-1.json
    └── annotation-2.json

# Grouped small/medium projects - shared machine  
modern-annotations/                        (repo → shared machine)
├── wwi-letters-letter-001/               (container = canvas)
│   ├── annotation-1.json
│   └── annotation-2.json
├── wwi-letters-letter-002/               (container = canvas)
│   └── annotation-1.json
└── wwii-photos-photo-001/                (container = canvas)
    ├── annotation-1.json
    └── annotation-2.json
```

**Key principle:** Each container corresponds to one canvas/page, since most viewers don't filter annotations by target. This ensures viewers only load annotations for the specific canvas being displayed, not the entire project.

## Container Routing

When running multiple deployments, you need a container → deployment index.

### Simple Index

A static YAML file maps each container to its deployment. A simple router (nginx, Traefik, or custom service) reads this file and forwards requests to the correct backend.

**Static YAML configuration:**
```yaml
# container-index.yaml
deployments:
  miiify-domesday:                    # Dedicated machine for large project
    url: http://miiify-domesday.internal:10000
    containers:
      - domesday-book-*               # All Domesday folios

  miiify-medieval:                    # Shared machine for grouped projects
    url: http://miiify-medieval.internal:10000
    containers:
      - magna-carta-*
      - bayeux-tapestry-*
      - lindisfarne-gospels-*
  
  miiify-modern:                      # Shared machine for grouped projects
    url: http://miiify-modern.internal:10000
    containers:
      - wwi-letters-*
      - wwii-photos-*
      - cold-war-documents-*
      
  miiify-small:                       # Shared machine for grouped projects
    url: http://miiify-small.internal:10000
    containers:
      - exhibition-2024-*
      - trial-*
      - workshop-*
```

**Result:** Using prefix patterns like `domesday-book-*` avoids listing hundreds of individual canvases - it matches all 400+ Domesday folios and routes them to the machine running Miiify on the `medieval-annotations` repository. A router (nginx, Traefik, or custom service) extracts the container name from the URL path and forwards the request to the appropriate deployment.

## Testing at Scale

To validate your scaling strategy and performance, you can generate large test datasets using the [generate_annotations.py](../scripts/generate_annotations.py) utility.

**Generate 10,000 annotations across 10 containers:**
```bash
python scripts/generate_annotations.py \
  --total 10000 \
  --containers 10 \
  --prefix my-canvas \
  --out ./test-annotations
```

**Then import, compile, and test:**
```bash
miiify-import --input ./test-annotations --git ./test-db-git
miiify-compile --git ./test-db-git --pack ./test-db-pack
miiify-serve --repository ./test-db-pack --port 10000
```

This allows you to:
- Benchmark compile times with realistic datasets
- Test API response times under load
- Validate your deployment strategy before production
- Experiment with different repository organization patterns

