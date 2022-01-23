## Kubernetes deployment

Some experimental instructions for running Miiify locally with Kong gateway providing read-only API access.

### Start minikube

```
minikube start
```

### Deploy with helm

```
helm install kong kong
helm install miiify miiify
helm install miiifyctl miiifyctl
```

### Start minikube tunnel

Running on port 80 so requires sudo access.

```
minikube tunnel
```

### Test the deployment

```
http :
```

```
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 18
Content-Type: text/html; charset=utf-8
Via: kong/2.7.0
X-Kong-Proxy-Latency: 1
X-Kong-Upstream-Latency: 1

Welcome to miiify!
```

### Get an annotation database

```
kubectl get pods
```

```
NAME                               READY   STATUS    RESTARTS   AGE
kong-deployment-84b4bdf6cd-frp4z   1/1     Running   0          2m44s
miiify-84c6fc9577-8t8st            1/1     Running   0          2m31s
miiify-84c6fc9577-d74br            1/1     Running   0          2m31s
miiifyctl-546ddcbd85-qkxwf         1/1     Running   0          2m17s
```

Access the block storage available in the pod.

```
kubectl exec -it miiifyctl-546ddcbd85-qkxwf -- sh
```

We will clone an existing annotation repo but we can also pull in changes if we have already cloned.

```
cd /data
rm -r db
git clone https://github.com/jptmoore/annotations.git db
exit
```

Restart Miiify to access the new annotation db. 

```
kubectl rollout restart deployment miiify
```

Get the total number of annotations available.

```
http :/annotations/demo/ | jq -r '.total'
```

