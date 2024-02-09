### Introduction

Miiify is a light-weight web annotation server using an embedded database. Its primary use case is to support [IIIF](https://iiif.io/) applications. There is a choice of two storage backends:

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

#### Check the server is running

```bash
http :
```

#### Stopping server
```bash
docker compose down pack
```

### Basic concepts

Annotations are organised into containers and can be retrieved in pages to display within IIIF viewers such as [Mirador](https://projectmirador.org/). To filter the annotation page to a specific IIIF canvas an additional target parameter can be supplied. The examples below use [httpie](https://httpie.io/) with a live demo server which spins down when inactive.

Create an annotation container called my-container:
```bash
https miiify.onrender.com/annotations/ < miiify/test/container1.json Slug:my-container
```

Add an annotation called foobar to my-container:
```bash
https miiify.onrender.com/annotations/my-container/ < miiify/test/annotation1.json Slug:foobar
```

Add another annotation but use a system generated id:
```bash
https miiify.onrender.com/annotations/my-container/ < miiify/test/annotation1.json
```

Retrieve the first annotation page from my-container:
```bash
https miiify.onrender.com/annotations/my-container/\?page\=0
```
produces:
```json
{
    "@context": "http://iiif.io/api/presentation/3/context.json",
    "id": "https://miiify.onrender.com/annotations/my-container/?page=0",
    "items": [
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post1",
            "created": "2023-12-07T17:13:18Z",
            "id": "https://miiify.onrender.com/annotations/my-container/4acb2493-96b2-4efb-a5aa-044cde1408f0",
            "target": "http://example.com/page1",
            "type": "Annotation"
        },
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post1",
            "created": "2023-12-07T17:11:44Z",
            "id": "https://miiify.onrender.com/annotations/my-container/foobar",
            "target": "http://example.com/page1",
            "type": "Annotation"
        }
    ],
    "partOf": {
        "created": "2023-12-07T17:10:20Z",
        "id": "https://miiify.onrender.com/annotations/my-container/",
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
https miiify.onrender.com/annotations/my-container/ < miiify/test/annotation3.json
https miiify.onrender.com/annotations/my-container/\?page\=0\&target\=http://example.com/page3
```
produces:
```json
{
    "@context": "http://iiif.io/api/presentation/3/context.json",
    "id": "https://miiify.onrender.com/annotations/my-container/?page=0&target=http://example.com/page3",
    "items": [
        {
            "@context": "http://www.w3.org/ns/anno.jsonld",
            "body": "http://example.org/post3",
            "created": "2023-12-07T17:15:47Z",
            "id": "https://miiify.onrender.com/annotations/my-container/20375636-3af4-44e4-b005-b5c5e625ec85",
            "target": "http://example.com/page3",
            "type": "Annotation"
        }
    ],
    "partOf": {
        "created": "2023-12-07T17:10:20Z",
        "id": "https://miiify.onrender.com/annotations/my-container/",
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
https miiify.onrender.com/annotations/my-container/foobar
```
produces
```json
{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post1",
    "created": "2023-12-07T17:11:44Z",
    "id": "https://miiify.onrender.com/annotations/my-container/foobar",
    "target": "http://example.com/page1",
    "type": "Annotation"
}
```

### Tutorial

Simple [video tutorial](https://miiifystore.s3.eu-west-2.amazonaws.com/presentations/simple-external-annotation.mp4) to show how to create annotations and display them in the Mirador IIIF viewer.

### Other key features

* Support for validating annotations using [ATD](https://atd.readthedocs.io/en/latest/atd-language.html#introduction)
* Easy to use with Docker and Kubernetes
* Support for ETag caching and collision avoidance
* Simple key/value interface for working with IIIF manifests

### Building from source

To build your own native Docker images:
```
cd miiify/test
./build.sh pack
```

### Documentation

[API specification](https://petstore.swagger.io/?url=https://raw.githubusercontent.com/nationalarchives/miiify/main/doc/swagger.yml)







