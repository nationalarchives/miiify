# Scaling Miiify

This document explains how to scale Miiify from a single project to institution-wide deployment serving millions of annotations.

**Note:** In this document, "container" refers to an annotation container (a collection of annotations as defined in the [W3C Web Annotation Data Model](https://www.w3.org/TR/annotation-model/#collections)), not Docker containers.

## Horizontal Scaling

**Miiify scales to millions of annotations** through simple horizontal partitioning - run multiple independent instances and route container requests to the appropriate deployment.

Miiify's read-only architecture enables simple horizontal scaling.

### Why Read-Only Scales Easily

**No write coordination:**
- No distributed locks
- No transaction coordination
- No eventual consistency problems
- No cache invalidation complexity

**Updates are offline:**
- Git PR → merge → compile → deploy
- Each deployment updates independently
- Atomic swap of Pack store
- Zero downtime deployments

## Repository Organization

### Strategy: Category-Based Repos

Organize repositories by intellectual/organizational category, with projects as containers within each repo.

**Structure:**
```
medieval-annotations/              (repo → deployment)
├── domesday-book/                 (container/project)
│   ├── folio-001-recto.json
│   ├── folio-001-verso.json
│   └── folio-002-recto.json
├── magna-carta/                   (container/project)
│   ├── clause-1.json
│   └── clause-39.json
├── bayeux-tapestry/               (container/project)
│   ├── scene-001.json
│   └── scene-002.json
└── lindisfarne-gospels/           (container/project)
    ├── page-001.json
    └── page-002.json

modern-annotations/                (repo → deployment)
├── wwi-letters/                   (container/project)
│   ├── letter-001.json
│   └── letter-002.json
├── wwii-photos/                   (container/project)
│   ├── photo-001.json
│   └── photo-002.json
└── cold-war-documents/            (container/project)
    ├── doc-001.json
    └── doc-002.json

victorian-annotations/             (repo → deployment)
├── industrial-revolution-docs/    (container/project)
│   └── report-1851.json
├── royal-correspondence/          (container/project)
│   └── letter-victoria-001.json
└── census-records/                (container/project)
    └── household-1891-001.json
```

**Why categories work:**
- Logical grouping aligns with institution structure
- Contributors share context and practices
- Can deploy category-sized chunks independently
- Natural boundaries (historical periods, departments)

**Naming convention:**
```
{institution}-{category}-annotations

Examples:
- institution-medieval-annotations
- institution-modern-annotations
- museum-ancient-annotations
```

### How to Organize

**Start simple:**
- One repo with all your annotations
- One deployment serving everything
- Works great up to ~500k annotations

**Grow by category when needed:**
- Split into category repos (medieval, modern, etc.)
- One deployment per category
- Each handles ~500k-1M annotations

**Pool small projects:**
- Group tiny projects together in one repo
- Saves resources, simplifies management

## Container Routing

When running multiple deployments, you need a container → deployment index.

### Simple Index (Recommended Start)

A static YAML file maps each container to its deployment. A simple router (nginx, Traefik, or custom service) reads this file and forwards requests to the correct backend.

**Static YAML configuration:**
```yaml
# container-index.yaml
deployments:
  miiify-medieval:
    url: http://miiify-medieval.internal:10000
    containers:
      - domesday-book
      - magna-carta
      - bayeux-tapestry
      - lindisfarne-gospels
  
  miiify-modern:
    url: http://miiify-modern.internal:10000
    containers:
      - wwi-letters
      - wwii-photos
      - cold-war-documents
      
  miiify-small:
    url: http://miiify-small.internal:10000
    containers:
      - exhibition-2024-*
      - trial-*
      - workshop-*
```

**Result:** Linear scaling - add deployments as needed, each handling ~500k-1M annotations independently.

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

