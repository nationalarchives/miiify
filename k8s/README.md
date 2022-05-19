## Kubernetes deployment

An example of running Miiify locally with Kong API gateway providing read-only API access. The deployment resembles the following:

![deployment](miiifyk8s.jpg | width=100)

The Kong gateway talks to a ReplicaSet containing 2 pods of Miiify that mount the same block storage. An additional Miiifyctl pod exists for mounting the storage to carry out Git commands. The pods all run within one node using minikube.

### Start minikube

```
minikube start
```

### Deploy with helm

```
helm install kong kong --set service.port=5000
helm install miiify miiify
helm install miiifyctl miiifyctl
```

### Start minikube tunnel

Running on port 5000.

```
minikube tunnel
```

### Test the deployment

```
http :5000
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
http :5000/annotations/demo/ | jq -r '.total'
```

