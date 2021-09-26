
### Getting started


Build from source and launch Docker container:
```bash
./deploy.sh
```

Create an annotation container:
```bash
cat test/container1.json | https :/annotations/ Slug:my-container --verify=no
```

Write 20 annotations to the container:
```bash
ab -c1 -n20 -p test/annotation1.json https://localhost/annotations/my-container/
```

Retrieve the contents of the container but display only the links to the annotations it contains:
```bash
https ":/annotations/my-container?page=0" Prefer:'return=representation;include="http://www.w3.org/ns/oa#PreferContainedIRIs"' --verify=no
```

Add an annotation called foobar to the container:
```bash
cat test/annotation1.json | https POST :/annotations/my-container/ Slug:foobar --verify=no
```

Retrieve the annotation called foobar:
```bash
https :/annotations/my-container/foobar --verify=no
```

Update the contents of the annotation called foobar:
```bash
cat test/annotation2.json | https PUT :/annotations/my-container/foobar --verify=no
```

Retrieve the updated contents of the annotation called foobar:
```bash
https :/annotations/my-container/foobar --verify=no
```

Examine the repository to see all the commits:
```bash
cd db
git log
```