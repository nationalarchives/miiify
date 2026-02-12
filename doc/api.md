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
GET /:container                # Get container metadata (AnnotationContainer)
GET /:container/               # Get collection with first page embedded
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

# Filter by target
curl "http://localhost:10000/my-canvas/?page=0&target=https://example.com/iiif/canvas/1"

# If your target contains characters like '#', URL-encode it:
curl --get \
  --data-urlencode "target=https://example.com/iiif/canvas/1#xywh=100,100,200,50" \
  "http://localhost:10000/my-canvas/?page=0"
```

## Response format

Single annotation:
```json
{
  "id": "http://localhost:10000/my-canvas/highlight-1",
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

Annotation page:
```json
{
  "id": "http://localhost:10000/my-canvas/?page=0",
  "type": "AnnotationPage",
  "startIndex": 0,
  "items": [
    {
      "id": "http://localhost:10000/my-canvas/highlight-1",
      "type": "Annotation",
      "body": { "...": "..." },
      "target": "https://example.com/iiif/canvas/1#xywh=100,100,200,50"
    }
  ],
  "partOf": {
    "id": "http://localhost:10000/my-canvas/",
    "type": "AnnotationContainer",
    "total": 42
  },
  "next": "http://localhost:10000/my-canvas/?page=1"
}
```
