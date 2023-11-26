### Introduction

Miiify is a light-weight web annotation server with its own embedded database technology. Its primary use case is to support [IIIF](https://iiif.io/) applications. There is a choice of two backends:

#### git

Designed to be compatible with the Git protocol. This means annotations can be added or edited using standard git flow mechanisms such as a pull request and all new content can go through a review process before going public. 

#### pack

Designed to be highly-scalable and disk efficient. This backend uses technology that is part of the distributed ledger used within the Tezos blockchain.

### Getting started

Miiify can be run with Docker using either the git or pack backend. The example below uses the pack backend.

#### Starting server

```bash
docker compose pull pack
docker compose up pack -d
```

### Stopping server
```bash
docker compose down pack
```

### Basic concepts

Annotations are organised into containers and can be retrieved in pages to display within annotation viewers such as [Mirador](https://projectmirador.org/). To filter the annotation page to a specific IIIF canvas an additional target parameter can be supplied.

Create an annotation container called my-container:
```bash
http http://localhost:8080/annotations/ < test/container1.json Slug:my-container
```

Add an annotation called foobar to my-container:
```bash
http http://localhost:8080/annotations/my-container/ < test/annotation1.json Slug:foobar
```

Add another annotation but use a system generated id:
```bash
http http://localhost:8080/annotations/my-container/ < test/annotation1.json
```

Retrieve the first annotation page from my-container:
```bash
http http://localhost:8080/annotations/my-container/\?page\=0
```
produces:
```json
{
    "@context": "http://iiif.io/api/presentation/3/context.json",
    "id": "http://localhost/annotations/my-container?page=0",
    "items": [
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post1",
            "created": "2023-11-26T16:30:47Z",
            "id": "http://localhost:8080/annotations/my-container/edd6a28b-b7a5-4c0c-88c6-a29377fffb8c",
            "target": "http://example.com/page1",
            "type": "Annotation"
        },
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post1",
            "created": "2023-11-26T16:32:27Z",
            "id": "http://localhost:8080/annotations/my-container/foobar",
            "target": "http://example.com/page1",
            "type": "Annotation"
        }
    ],
    "partOf": {
        "created": "2023-11-26T16:28:53Z",
        "id": "http://localhost/annotations/my-container",
        "label": "A Container for Web Annotations",
        "total": 2,
        "type": "AnnotationCollection"
    },
    "startIndex": 0,
    "type": "AnnotationPage"
}
```

Retrieve the first annotation page from my-container but filter annotations based on their target:
```bash
http http://localhost:8080/annotations/my-container/ < test/annotation3.json
http http://localhost:8080/annotations/my-container/\?page\=0\&target\=http://example.com/page3
```
produces:
```json
{
    "@context": "http://iiif.io/api/presentation/3/context.json",
    "id": "http://localhost/annotations/my-container?page=0&target=http://example.com/page3",
    "items": [
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post3",
            "created": "2023-11-26T17:02:10Z",
            "id": "http://localhost:8080/annotations/my-container/ca04c632-b093-44b8-8785-0c985b2ff036",
            "target": "http://example.com/page3",
            "type": "Annotation"
        }
    ],
    "partOf": {
        "created": "2023-11-26T16:28:53Z",
        "id": "http://localhost/annotations/my-container",
        "label": "A Container for Web Annotations",
        "total": 3,
        "type": "AnnotationCollection"
    },
    "startIndex": 0,
    "type": "AnnotationPage"
}
```

Retrieve a single annotation:
```bash
http http://localhost:8080/annotations/my-container/foobar
```
produces
```json
{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post1",
    "created": "2023-11-26T16:32:27Z",
    "id": "http://localhost:8080/annotations/my-container/foobar",
    "target": "http://example.com/page1",
    "type": "Annotation"
}
```

 
### Other key features

* Support for ETag caching
* Simple key/value interface for working with IIIF manifests
* Easily scaled horizontally using Kubernetes









