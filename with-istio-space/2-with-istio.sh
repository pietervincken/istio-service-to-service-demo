#!/bin/sh

export NAMESPACE=with-istio

## Create namespace with Istio injection enabled.
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE istio-injection=enabled

## Deploy CouchDB
helm template --name couchdb ./couchdb > build/couchdb.yaml
kubectl apply -f build/couchdb.yaml --namespace $NAMESPACE

# Initialise CouchDB
kubectl exec --namespace $NAMESPACE couchdb-0 -c couchdb -- \
    curl -s \
    http://127.0.0.1:5984/_cluster_setup \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action": "finish_cluster"}'

## Build and deploy app
# Builds it. This only works because the docker-desktop and kubernetes share the same docker cache. When using an online cluster, push the image to a registry
docker build -f test-app/Dockerfile -t test-app:latest test-app/ 
helm template --name test-app ./test-app/test-app-chart > build/test-app.yaml
kubectl apply -f build/test-app.yaml --namespace $NAMESPACE

## Add a test doc to CouchDB
kubectl exec --namespace $NAMESPACE couchdb-0 -c couchdb -- \
    curl -s \
    http://127.0.0.1:5984/animals \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"hello":"world", "_id":"test"}'

## Open port forwarding and show that API is working.
kubectl port-forward -n $NAMESPACE svc/test-app-test-app-chart 8080:80

## Start a watch to test the API
watch -n 1 curl -sq http://localhost:8080/api/v1/animals/test

## Enable RBAC in with-istio space
kubectl apply -f with-istio-space/rbac-config.yaml

## Show that the requests are failing now. This may take up to 60s to happen. 

## Create couchdb-role. This is the role that allows access to couchdb
kubectl apply -f with-istio-space/couchdb-role.yaml 

## Create role binding for test-app service account to the couchdb-role
kubectl apply -f with-istio-space/test-app-couchdb-rolebinding.yaml

## Now the API should have access again. 

## Deploy the same app to the same namespace -> no access. 
helm template --name test-app-2 ./test-app/test-app-chart > build/test-app-2.yaml
kubectl apply -f build/test-app-2.yaml --namespace $NAMESPACE

## Port forward the new service
kubectl port-forward -n $NAMESPACE svc/test-app-2-test-app-chart 8081:80

## Try to access the second service
watch curl -sq http://localhost:8081/api/v1/animals/test
