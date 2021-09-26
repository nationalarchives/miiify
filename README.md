```bash
./deploy.sh
cat test/container1.json | https :/annotations/ Slug:my-container --verify=no
ab -c1 -n20 -p test/annotation1.json https://localhost/annotations/my-container/
https ":/annotations/my-container?page=1" Prefer:'return=representation;include="http://www.w3.org/ns/oa#PreferContainedIRIs"' --verify=no
cat test/annotation1.json | https POST :/annotations/my-container/ Slug:foobar --verify=no
https :/annotations/my-container/foobar --verify=no
cat test/annotation2.json | https PUT :/annotations/my-container/foobar --verify=no
https :/annotations/my-container/foobar --verify=no
cd db
git log
```