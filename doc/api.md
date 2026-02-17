# HTTP API

Miiify serves a read-only HTTP API for retrieving annotations.

## URL structure

Annotations use a simple `/<container>/<slug>` URL pattern:
- **Container**: directory name (e.g., `my-canvas`, `page-42`)
- **Slug**: filename without `.json` extension (e.g., `highlight-1`, `comment-3`)
- Both formats work: `/<container>/<slug>` and `/<container>/<slug>.json`

## Endpoints

```
GET /                          # Server status
GET /version                   # Version info
GET /:container/               # Get collection with first page embedded (AnnotationCollection)
GET /:container/?page=N        # Get specific page (AnnotationPage)
GET /:container/:slug          # Get specific annotation
```

## Examples

```bash
# Get annotation (both work)
curl http://localhost:10000/my-canvas/highlight-1
curl http://localhost:10000/my-canvas/highlight-1.json

# Get collection with first page embedded
curl http://localhost:10000/my-canvas/

# Get specific page
curl http://localhost:10000/my-canvas/?page=0
curl http://localhost:10000/my-canvas/?page=1
```

## Efficient caching with ETags

Miiify implements **content-based ETags** for all resources, enabling highly efficient caching and bandwidth optimization.

### How it works

Every response includes an `ETag` header containing a hash of the content:

```bash
$ curl -i http://localhost:10000/my-canvas/highlight-1
HTTP/1.1 200 OK
ETag: "a3f5b8c9d2e1"
Content-Type: application/json

{"id":"http://localhost:10000/my-canvas/highlight-1"...}
```

Clients can use `If-None-Match` to avoid re-downloading unchanged content:

```bash
$ curl -i -H 'If-None-Match: "a3f5b8c9d2e1"' http://localhost:10000/my-canvas/highlight-1
HTTP/1.1 304 Not Modified
ETag: "a3f5b8c9d2e1"
```

No response body is sent - saving bandwidth and processing time.

### Performance benefits

- **Zero-copy reads**: ETags derived from stored content hashes (no re-computation)
- **Instant validation**: Hash comparison happens before deserialization
- **CDN-friendly**: Standard HTTP caching works out of the box
- **Bandwidth savings**: 304 responses are typically <200 bytes vs. full JSON

**Why it's fast:** Miiify uses Irmin, a content-addressed storage system where every piece of data is already identified by its hash. ETags are derived directly from these internal content hashes - meaning:

- No additional hash computation needed
- No separate ETag generation or storage
- Hashes are immutable and cached in memory
- ETag lookup is a single hash table access

This architecture makes conditional requests effectively **free** - the "cost" is a memory lookup, not content processing.

### ETag coverage

ETags are provided for all resources:

| Resource | ETag includes |
|----------|---------------|
| Annotation | Content hash |
| Collection | Content hash + limit parameter |
| Page | Content hash + limit + page number |

### Example workflow

```bash
# First request - full response (e.g., 2KB)
curl -i http://localhost:10000/my-canvas/ > collection.json

# Extract ETag
ETAG=$(grep -i 'etag:' collection.json | cut -d'"' -f2)

# Subsequent requests - 304 if unchanged (~150 bytes)
curl -i -H "If-None-Match: \"$ETAG\"" http://localhost:10000/my-canvas/
```

### CDN/Proxy deployment

ETags make miiify ideal for deployment behind CDNs or reverse proxies:

- Cloudflare, Fastly, nginx automatically cache based on ETags
- No application-layer cache invalidation needed
- Content changes reflected immediately via new ETags
- Reduces load on origin server
