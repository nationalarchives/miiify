### Introduction

Miiify is an experimental W3C annotation server that is based on the [Web Annotation Protocol](https://www.w3.org/TR/annotation-protocol/). 

Rather than rely on running a centralised infrastructure, Miiify adopts a distributed approach to collaboration using a peer review process facilitated on GitHub. Each user interacts with their own instance of Miiify using a web interface that supports annotating content such as images. Contributions are then submitted back to the main GitHub repository through a pull request. A simple example annotation app is available [here](https://github.com/jptmoore/miiifyapp).

The rest of the documentation here describes the backend component of the stack which is useful for those building their own annotation interfaces.

### Quick start

The following tutorial demonstrates how to interact with the server using the httpie [tool](https://httpie.io/) and Apache Benchmark [tool](https://httpd.apache.org/docs/2.4/programs/ab.html). Note, the server is running from a self-signed certificate generated within the Docker container.

Build from source and launch Docker container (note this will take some time the first run):
```bash
./deploy.sh
```

Create an annotation container:
```bash
cat test/container1.json | https :/annotations/ Slug:my-container --verify=no
```

```json
HTTP/1.1 201 Created
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 257
Link: <http://www.w3.org/ns/ldp#BasicContainer>; rel="type"
Link: <http://www.w3.org/ns/oa#AnnotationCollection>; rel="type"
Link: <http://www.w3.org/TR/annotation-protocol/>; "http://www.w3.org/ns/ldp#constrainedBy"

{
    "@context": [
        "http://www.w3.org/ns/anno.jsonld",
        "http://www.w3.org/ns/ldp.jsonld"
    ],
    "created": "2021-09-26T20:13:01Z",
    "id": "https://localhost/annotations/my-container",
    "label": "A Container for Web Annotations",
    "type": [
        "BasicContainer",
        "AnnotationCollection"
    ]
}
```

Write 20 annotations to the container:
```bash
ab -c1 -n20 -p test/annotation1.json https://localhost/annotations/my-container/
```

Retrieve the contents of the container but display only the links to the annotations it contains:
```bash
https ":/annotations/my-container?page=0" Prefer:'return=representation;include="http://www.w3.org/ns/oa#PreferContainedIRIs"' --verify=no
```

```json
HTTP/1.1 200 OK
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 2011
ETag: "ae554ea75c6bc705ebfc6352e481bca265e14f21"
Link: <http://www.w3.org/ns/oa#AnnotationPage>; rel="type"

{
    "@context": [
        "http://www.w3.org/ns/anno.jsonld",
        "http://www.w3.org/ns/ldp.jsonld"
    ],
    "id": "https://localhost/annotations/my-container?page=0",
    "items": [
        "https://localhost/annotations/my-container/0f264d28-304b-478d-adb8-d9520152a14a",
        "https://localhost/annotations/my-container/22e230bc-453a-4065-833b-f6e9cae5e795",
        "https://localhost/annotations/my-container/29e7dac6-9291-4570-b1f0-8060fdcca745",
        "https://localhost/annotations/my-container/329399e6-2495-4df0-9043-d2b3a21737ea",
        "https://localhost/annotations/my-container/3f9788d1-ca1e-4e55-a76f-d862eeaa8b15",
        "https://localhost/annotations/my-container/3fb8c4f6-9b0f-4850-89b3-1529ba0529ec",
        "https://localhost/annotations/my-container/4b0f2fce-ebd5-442d-83c3-90fd73978b45",
        "https://localhost/annotations/my-container/4c17603a-c6bb-4da1-b982-c8aa6f227e84",
        "https://localhost/annotations/my-container/855c97e8-fd98-4890-8a23-4e9a9e922435",
        "https://localhost/annotations/my-container/8780348d-a9a3-478c-9ef6-314af741b396",
        "https://localhost/annotations/my-container/89cbdf50-fc75-40ea-a46c-1152661ce890",
        "https://localhost/annotations/my-container/a16eff98-15c1-48ab-bec0-bbd6920fb700",
        "https://localhost/annotations/my-container/ad13d742-f520-4563-ad03-938d963bbf5e",
        "https://localhost/annotations/my-container/b1cf1b97-0de9-43d7-be7a-a831d80aaf1c",
        "https://localhost/annotations/my-container/b29bde18-9382-49a7-9f4f-03fa27700b7f",
        "https://localhost/annotations/my-container/c94bde54-a5d6-4538-8590-5ce9154afe50",
        "https://localhost/annotations/my-container/d3081bec-304d-4ae9-8bd1-94c70ed2dce1",
        "https://localhost/annotations/my-container/f0cbfb2c-f042-4882-b125-6f12cc20ebe3",
        "https://localhost/annotations/my-container/fb69b6ee-902f-432b-a2cd-05d659f056b3",
        "https://localhost/annotations/my-container/fe363b92-b462-4acf-925d-805ca7f87572"
    ],
    "partOf": {
        "created": "2021-09-26T20:13:01Z",
        "id": "https://localhost/annotations/my-container/",
        "label": "A Container for Web Annotations",
        "modified": "2021-09-26T20:14:16Z",
        "total": 20
    },
    "startIndex": 0,
    "type": "AnnotationPage"
}
```

Add an annotation called foobar to the container:
```bash
cat test/annotation1.json | https POST :/annotations/my-container/ Slug:foobar --verify=no
```

```json
HTTP/1.1 201 Created
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 227
Link: <http://www.w3.org/ns/ldp#Resource>; rel="type"

{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post1",
    "created": "2021-09-26T20:16:12Z",
    "id": "https://localhost/annotations/my-container/foobar",
    "target": "http://example.com/page1",
    "type": "Annotation"
}
```

Retrieve the annotation called foobar:
```bash
https :/annotations/my-container/foobar --verify=no
```

```json
HTTP/1.1 200 OK
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 227
ETag: "d2194a437f6e66618ed51007c7bff0937c503e10"
Link: <http://www.w3.org/ns/ldp#Resource>; rel="type"

{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post1",
    "created": "2021-09-26T20:16:12Z",
    "id": "https://localhost/annotations/my-container/foobar",
    "target": "http://example.com/page1",
    "type": "Annotation"
}
```

Update the contents of the annotation called foobar:
```bash
cat test/annotation2.json | https PUT :/annotations/my-container/foobar --verify=no
```

```json
HTTP/1.1 200 OK
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 228
Link: <http://www.w3.org/ns/ldp#Resource>; rel="type"

{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post2",
    "id": "https://localhost/annotations/my-container/foobar",
    "modified": "2021-09-26T20:17:18Z",
    "target": "http://example.com/page2",
    "type": "Annotation"
}
```

Retrieve the updated contents of the annotation called foobar:
```bash
https :/annotations/my-container/foobar --verify=no
```

```json
HTTP/1.1 200 OK
Content-Type: application/ld+json; profile="http://www.w3.org/ns/anno.jsonld"
Content-length: 228
ETag: "caa80ca1e4cc5f2253df5ee35293236350b19194"
Link: <http://www.w3.org/ns/ldp#Resource>; rel="type"

{
    "@context": "http://www.w3.org/ns/anno.jsonld",
    "body": "http://example.org/post2",
    "id": "https://localhost/annotations/my-container/foobar",
    "modified": "2021-09-26T20:17:18Z",
    "target": "http://example.com/page2",
    "type": "Annotation"
}
```

Examine the repository to see some commits:
```bash
cd db ; git log -n3
```

```bash
commit 886382c41f40d1a82563fa972bb12bd1faa6fa4d (HEAD -> master)
Author: miiify.rocks <irmin@openmirage.org>
Date:   Sun Sep 26 20:17:18 2021 +0000

    PUT without etag /my-container/collection/foobar

commit 46781a655b17e00943e910c57cac2f516567c509
Author: miiify.rocks <irmin@openmirage.org>
Date:   Sun Sep 26 20:16:12 2021 +0000

    POST /my-container/collection/foobar

commit 25631aa20a56d009e819e00c77efae8aaaf43dee
Author: miiify.rocks <irmin@openmirage.org>
Date:   Sun Sep 26 20:16:12 2021 +0000

    POST /my-container/main/modified
```

The latest commit message above shows that a PUT (update) was carried out to the foobar annotation but an ETag was not used. ETag support is added for supporting caching of resources as well as ensuring that an update or delete operation takes places on the intended resource without subsequent unknown modifications. ETag support works by storing the value obtained from a GET or HEAD request and then using this in future requests. Note that your commit hashes will be different than in these examples:
```bash
https :/annotations/my-container/foobar If-None-Match:"caa80ca1e4cc5f2253df5ee35293236350b19194" --verify=no 
```
If there is no change to an annotation or container collection the server will respond back with a Not Modified status to inform the client that the cached version of the response is still good to use:
```bash
HTTP/1.1 304 Not Modified
Content-Length: 0
```

To safely update the resource earlier we could have supplied the ETag as follow:
```bash
cat test/annotation2.json | https PUT :/annotations/my-container/foobar If-Match: "d2194a437f6e66618ed51007c7bff0937c503e10" --verify=no
```
This ensures we really are updating the resource that we think we are.

### API

The API has been described using [OpenAPI](https://github.com/nationalarchives/miiify/blob/main/doc/swagger.yml).


### Configuration

The server can be started with the command flag ```--config=<file>``` to specify a JSON configuration file. The sample below shows all the fields with their default values when not included:

```json
{
  "https": true,
  "interface": "0.0.0.0",
  "port": 8080,
  "debug": false,
  "certificate_file": "server.crt",
  "key_file": "server.key",
  "repository_name": "db",
  "repository_author": "miiify.rocks",
  "container_page_limit": 200,
  "container_representation": "PreferContainedDescriptions"
}
```
The default is to use HTTPS which will require certificates. For testing you can generate some self-signed certs. For example:
```bash
openssl req -x509 -out server.crt -keyout server.key \
  -newkey rsa:2048 -nodes -sha256 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
```

### Testing

Tests can be run using the [Airborne](https://github.com/brooklynDev/airborne) test framework:

```bash
docker-compose up -d
cd test
rspec integration.rb -fd
docker-compose down
```


