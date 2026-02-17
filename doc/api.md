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

Miiify implements [HTTP ETags](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) for all resources, enabling efficient caching and bandwidth optimization. Because Miiify uses Irmin (a content-addressed storage system), ETags come **for free** - they're derived directly from internal content hashes without any additional computation or storage overhead. This makes conditional requests essentially zero-cost and allows standard CDN/proxy caching to work out of the box.
