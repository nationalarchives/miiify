# Miiify Storage Internals

This document describes the storage format and architecture used by Miiify's dual-backend system.

## Storage Backends

Miiify uses two Irmin storage backends for different purposes:

- **Git Store**: User-facing, flat structure for version control and collaboration
- **Pack Store**: Optimized hierarchical structure for high-performance serving

### Git Protocol Support

Git operations use **Irmin's native Git implementation** (`Irmin_git_unix.FS`), not external git CLI commands:

- `Sync.fetch` - Clone remote repositories
- `Sync.pull` - Pull and merge updates
- `Store.remote` - Configure Git remotes

This provides direct Git protocol support without shelling out to external processes.

## Git Store Format (User-Facing)

Git repos use a **flat 2-level key structure** with only annotation data:

```
[container_id; slug] → JSON annotation data
```

### Example: Git Structure

```
["my-canvas"; "highlight-1"] → {"type":"Annotation","motivation":"highlighting",...}
["my-canvas"; "comment-1"] → {"type":"Annotation","motivation":"commenting",...}
```

**Why flat?** This mirrors the simple filesystem structure users see on GitHub:

```
my-canvas/
  highlight-1.json
  comment-1.json
```

**No container metadata in Git.** The Git repo only contains annotation files. Container metadata is generated during compilation.

## Pack Store Format (Internal)

Pack uses a **hierarchical 3-level key structure** for optimized access:

```
[container_id; "collection"; slug] → JSON annotation data
[container_id; "metadata"] → JSON container metadata (generated during compile)
```

### Example: Pack Structure

```
["my-canvas"; "metadata"] → {"type":"AnnotationCollection","label":"my-canvas","created":"..."}
["my-canvas"; "collection"; "highlight-1"] → {"type":"Annotation",...}
["my-canvas"; "collection"; "highlight-2"] → {"type":"Annotation",...}
```

**Why hierarchical?** The intermediate "collection" level enables:
- Fast enumeration of all annotations in a container
- Efficient tree traversal for pagination
- Separation of metadata (`metadata`) from collection items

**Container metadata generated at compile time.** The `metadata` entry is automatically created with type, label, and creation timestamp.

## Transformation During Compile

The `miiify-compile` command performs two operations:

1. **Creates container metadata** in Pack (not in Git):

```ocaml
(* Generated for each container *)
[container; "metadata"] → {"type":"AnnotationCollection","label":"container","created":"2026-02-11T23:00:00Z"}
```

2. **Transforms Git's flat structure to Pack's hierarchical format**:

```ocaml
(* Git key *)
["container"; "slug"] 

(* Transform to Pack key *)
["container"; "collection"; "slug"]
```

**Code:**
```ocaml
(* Create container metadata *)
let container_json = Printf.sprintf 
  {|{"type":"AnnotationCollection","label":"%s","created":"%s"}|} 
  container timestamp

(* Transform annotation keys *)
let pack_path = match git_path with
  | [container; slug] -> [container; "collection"; slug]
  | _ -> failwith "unexpected structure"
```

## Value Format

All values are **JSON strings** conforming to the W3C Web Annotation Data Model:

```json
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
```

Container metadata is also JSON:

```json
{
  "type": "AnnotationCollection",
  "label": "my-canvas",
  "created": "2026-02-11T23:00:00Z"
}
```

## Workflow

### Import Workflow
```
Filesystem (flat: container/file.json)
  ↓ miiify-import
Git Store (flat: [container; slug] - annotations only)
  ↓ miiify-compile (generates metadata + inserts "collection")
Pack Store (hierarchical: [container; "metadata"] + [container; "collection"; slug])
  ↓ miiify-serve
HTTP API (with runtime IDs injected)
```

### Clone Workflow
```
Remote Git (flat: [container; slug] - annotations only)
  ↓ miiify-clone
Local Git Store (flat: [container; slug] - annotations only)
  ↓ miiify-compile (generates metadata + inserts "collection")
Pack Store (hierarchical: [container; "metadata"] + [container; "collection"; slug])
  ↓ miiify-serve
HTTP API (with runtime IDs injected)
```

## Design Rationale

**Git = Human Interface**
- Flat structure mirrors filesystem
- Easy to browse on GitHub
- Simple mental model for users
- Direct mapping to file layout

**Pack = Machine Optimization** 
- Hierarchical for efficient serving
- Fast tree operations for pagination
- Optimized binary storage format
- Internal implementation detail

**Compile = Single Transformation Point**
- Clear separation of concerns
- Git changes don't affect serving
- Pack optimizations don't leak to users
- Simple to reason about

## ID Injection

IDs are **not stored** in either backend. They are injected at runtime during serving:

```ocaml
(* Stored in Pack *)
["container"; "collection"; "slug"] → {"type":"Annotation",...}

(* Served via HTTP with injected ID *)
{"id":"http://localhost:10000/container/slug","type":"Annotation",...}
```

IDs are constructed from:
- Base URL (configurable via `--base-url`)  
- Container name (from key)
- Slug (from key)

This allows changing the base URL without modifying stored data.
