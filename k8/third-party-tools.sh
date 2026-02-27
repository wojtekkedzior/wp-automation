#!/bin/bash

function istio() {
    # helm repo add istio https://istio-release.storage.googleapis.com/charts
    echo "TODO"

    kubectl create namespace istio-system
    helm install istio-base istio/base -n istio-system --set defaultRevision=default
    helm install istiod istio/istiod -n istio-system --wait

    kubectl create namespace istio-ingress
    helm install istio-ingressgateway istio/gateway -n istio-ingress

    #TODO

    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

    curl -L https://istio.io/downloadIstio | sh -
    kubectl apply -f istio-1.20.0/samples/addons/prometheus.yaml
    kubectl apply -f istio-1.20.0/samples/addons/kiali.yaml

}

function couchBase() {
    # https://docs.couchdb.org/en/stable/install/kubernetes.html
    # helm repo add couchdb https://apache.github.io/couchdb-helm
    # helm repo update
    helm upgrade --install cb couchdb/couchdb -f 3rd-party-values/couch-base.yaml
}

function vpa() {
    echo "TODO"
    #TODO
}

function hpa() {
    echo "TODO"
    #TODO
    #TODO - include metrics server
}

function hazelcast() {
    # helm repo add hazelcast https://hazelcast-charts.s3.amazonaws.com/

    helm upgrade --install my-release hazelcast/hazelcast -f 3rd-party-values/hazelcast-values.yaml #--set cluster.memberCount=3
    sleep 2
    sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
}

function nginx() {
    kubectl apply -f nginx/nginx.yaml -n litmus
}

function litmus() {    
    # Randomly selected worker 1 to load litmus config
    workerIp=$(kubectl get nodes --field-selector metadata.name=worker-1-135 -o json | jq -r '.items[0].status.addresses[0].address')

    # controlPlane=192.168.1.34

    kubectl create ns litmus

    # installing from local because the mongodb chart uses an initContainer from an archive repo which has been removed. I update the initContainer to use a new image.
    helm install chaos ./litmus/chaos/litmus --namespace=litmus --set portal.frontend.service.type=NodePort --set portal.frontend.service.nodePort=30004
    
    # but we can install the kubernetes-chaos chart from the helm repo
    helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
    helm install kube-chaos litmuschaos/kubernetes-chaos --namespace=litmus  --version 3.19.0

    kubectl -n litmus apply -f litmus/chaos/chaos-rbac.yaml

    password="Litmus1!"
    ct="Content-Type: application/json"
    a="Accept: application/json"
    
    # litmus takes a while to get going
    sleep 60

    # 1.
    bearerToken=$(curl -s -X POST http://${workerIp}:30004/auth/login -H "${ct}" -H "${a}" -d '{"username": "admin", "password": "litmus"}' | jq -r '.accessToken')
    echo "initial login done. Bearer: ${bearerToken}"

    # 2.
    curl -s -X POST http://${workerIp}:30004/auth/update/password -H "${ct}" -H "${a}" -d '{"username": "admin", "oldPassword": "litmus", "newPassword": "'${password}'"}' -H "Authorization: Bearer ${bearerToken}"

    # 3. 
    rm ~/.litmusconfig

    #install from https://github.com/litmuschaos/litmusctl#installation
    litmusctl config set-account -n --endpoint "http://${workerIp}:30004" --password "${password}" --username "admin"

    # 4.
    litmusctl create project --name test-project
    projectId=$(litmusctl get projects -o json | jq -r '.projects[] | select(.name=="test-project") | .projectID')

    # 5.
    litmusctl create chaos-environment --project-id="${projectId}" --name="new-chaos-environment"

    # 6.
    litmusctl connect chaos-infra --name="new-chaos-infra" --environment-id="new_chaos_environment" --project-id="${projectId}" --non-interactive

    # start test deployment
    nginx
}