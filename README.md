### Introduction

Miiify is an experimental W3C annotation server that is based on the [Web Annotation Protocol](https://www.w3.org/TR/annotation-protocol/). 

Rather than rely on running a centralised infrastructure, Miiify adopts a distributed approach to collaboration using a peer review process facilitated on GitHub. Each user interacts with their own instance of Miiify using a web interface that supports annotating content such as images. Contributions are then submitted back to the main GitHub repository through a pull request. An example annotation [app](https://github.com/jptmoore/miiifyapp) and [annotation](https://github.com/jptmoore/annotations) repo is available for testing. The rest of the documentation here describes the backend component of the stack which is useful for those building their own annotation interfaces.

### Features

* Talks native git (no database required)
* No requirement to support user authentication or accounts
* Browsable JSON content
* Light-weight (docker image less than 60MB)
* Simple Key/Value interface for working with manifests

### Quick start

Run pre-built Docker image:
```bash
docker pull jptmoore/miiify
./deploy.sh
```

Build from source and launch Docker container (note this will take some time the first run and sometimes breaks on build changes):
```bash
./deploy-from-source.sh
```

Create an annotation container:
```bash
curl -k -d @test/container1.json https://localhost/annotations/ -H Slug:my-container
```

```json
{
  "@context": [
    "http://www.w3.org/ns/anno.jsonld",
    "http://www.w3.org/ns/ldp.jsonld"
  ],
  "type": [
    "BasicContainer",
    "AnnotationCollection"
  ],
  "label": "A Container for Web Annotations",
  "id": "https://localhost/annotations/my-container",
  "created": "2022-04-26T14:12:39Z"
}
```

Write some annotations to the container:
```bash
curl -k -d @test/annotation1.json https://localhost/annotations/my-container/
curl -k -d @test/annotation1.json https://localhost/annotations/my-container/
curl -k -d @test/annotation1.json https://localhost/annotations/my-container/
```

Retrieve the contents of the container but display only the links to the annotations it contains:
```bash
curl -k "https://localhost/annotations/my-container?page=0" -H Prefer:'return=representation;include="http://www.w3.org/ns/oa#PreferContainedIRIs"'
```

```json
{
  "@context": [
    "http://www.w3.org/ns/anno.jsonld",
    "http://www.w3.org/ns/ldp.jsonld"
  ],
  "id": "https://localhost/annotations/my-container?page=0",
  "type": "AnnotationPage",
  "partOf": {
    "id": "https://localhost/annotations/my-container/",
    "created": "2022-04-26T14:12:39Z",
    "modified": "2022-04-26T14:24:05Z",
    "total": 3,
    "label": "A Container for Web Annotations"
  },
  "startIndex": 0,
  "items": [
    "https://localhost/annotations/my-container/354b14bd-8ad5-4261-8e81-dd70a6758c2f",
    "https://localhost/annotations/my-container/56c3df84-da68-40b3-8d22-d37cd5ec3571",
    "https://localhost/annotations/my-container/c6f45c55-58d0-4510-b978-39585f22fd1d"
  ]
}
```

Add an annotation called foobar to the container:
```bash
curl -k -d @test/annotation1.json https://localhost/annotations/my-container/ -H Slug:foobar
```

```json
{
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "type": "Annotation",
  "body": "http://example.org/post1",
  "target": "http://example.com/page1",
  "id": "https://localhost/annotations/my-container/foobar",
  "created": "2022-04-26T14:30:26Z"
}
```

Retrieve the annotation called foobar:
```bash
curl -k https://localhost/annotations/my-container/foobar
```

```json
{
  "type": "Annotation",
  "target": "http://example.com/page1",
  "id": "https://localhost/annotations/my-container/foobar",
  "created": "2022-04-26T14:30:26Z",
  "body": "http://example.org/post1",
  "@context": "http://www.w3.org/ns/anno.jsonld"
}
```

Update the contents of the annotation called foobar:
```bash
curl -k -X PUT -d @test/annotation2.json https://localhost/annotations/my-container/foobar
```

```json
{
  "@context": "http://www.w3.org/ns/anno.jsonld",
  "id": "https://localhost/annotations/my-container/foobar",
  "type": "Annotation",
  "body": "http://example.org/post2",
  "target": "http://example.com/page2",
  "modified": "2022-04-26T14:35:25Z"
}
```

ETag support is added for supporting caching of resources as well as ensuring that an update or delete operation takes places on the intended resource without subsequent unknown modifications. ETag support works by using the value obtained from a GET or HEAD request and then using this in future requests. 
```bash
curl -k -I https://localhost/annotations/my-container/foobar
```
```
HTTP/2 200 
etag: "c25c28a70db07c843253001dabfab6d8ebc7a76f"
content-type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
link: <http://www.w3.org/ns/ldp#Resource>; rel="type"
```
Note that your ETag hashes will be different from these examples:
```bash
curl -k -I https://localhost/annotations/my-container/foobar -H If-None-Match:c25c28a70db07c843253001dabfab6d8ebc7a76f
```
If there is no change to an annotation or container collection the server will respond back with a Not Modified status to inform the client that the cached version of the response is still good to use:
```
HTTP/2 304 
```
To safely update the resource earlier we could have supplied the ETag as follows:
```bash
curl -k -X PUT -d @test/annotation2.json https://localhost/annotations/my-container/foobar -H If-Match:c25c28a70db07c843253001dabfab6d8ebc7a76f
```
This ensures we really are updating the resource that we think we are.

### Manifests

Miiify provides a simple Key/Value interface for working with manifests which are also stored using Git in a directory called '.manifest'.

To store a manifest using key 'foo':
```bash
curl -k -X POST -d @test/manifest1.json https://localhost/manifest/foo
```

To update a manifest using key 'foo':
```bash
curl -k -X PUT -d @test/manifest1.json https://localhost/manifest/foo
```

To retrieve a manifest using key 'foo':
```bash
curl -k https://localhost/manifest/foo
```

To delete a manifest using key 'foo':
```bash
curl -k -X DELETE https://localhost/manifest/foo
```

### API

The API has been described using [OpenAPI](https://github.com/nationalarchives/miiify/blob/main/doc/swagger.yml).


### Configuration

The server can be started with the command flag ```--config=<file>``` to specify a JSON configuration file. The sample below shows all the fields with their default values when not included:

```json
{
  "tls": true,
  "interface": "0.0.0.0",
  "port": 8080,
  "certificate_file": "server.crt",
  "key_file": "server.key",
  "repository_name": "db",
  "repository_author": "miiify.rocks",
  "container_page_limit": 200,
  "container_representation": "PreferContainedDescriptions"
}
```

### Testing

Tests can be run using the [Airborne](https://github.com/brooklynDev/airborne) test framework:

```bash
docker compose up -d
cd test
rspec integration.rb -fd
docker compose down
```


