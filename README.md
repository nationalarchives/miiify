```bash
./deploy.sh
cat test/container1.json | http :/annotations/ Slug:my-container
ab -c1 -n250 -p test/annotation1.json localhost/annotations/my-container/
http ":/annotations/my-container?page=1" Prefer:'return=representation;include="http://www.w3.org/ns/oa#PreferContainedIRIs"'
cat test/annotation1.json | http POST :/annotations/my-container/ Slug:foobar
http :/annotations/my-container/foobar
cat test/annotation2.json | http PUT :/annotations/my-container/foobar
http :/annotations/my-container/foobar
cd db
git log
git show
docker run -v ~/git/miiify/db:/db \
           -p 7777:80 \
           -it jonashaag/klaus:latest \
           klaus --host 0.0.0.0 --port 80 /db
```