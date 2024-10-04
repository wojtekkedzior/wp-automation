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
    kubectl apply -f k8-cluster/nginx.yaml
}


function litmus() {
    # https://github.com/litmuschaos/litmus-helm

    
    helm repo add litmuschaos https://litmuschaos.github.io/litmus-helm/
    kubectl create ns litmus
    helm install chaos litmuschaos/litmus --namespace=litmus --set portal.frontend.service.type=NodePort

    kubectl apply -f https://litmuschaos.github.io/litmus/litmus-operator-v2.2.0.yaml
    kubectl apply -f https://hub.litmuschaos.io/api/chaos/2.2.0?file=charts/generic/pod-network-latency/experiment.yaml

    # for the the service to get an IP
    sleep 3

    sudo sed -i "/setenv LITMUS_UI_IP/c\\\tsetenv LITMUS_UI_IP $(kubectl -n litmus get svc chaos-litmus-frontend-service -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    kubectl apply -f https://raw.githubusercontent.com/litmuschaos/litmus/master/mkdocs/docs/3.6.1/litmus-portal-crds-3.6.1.yml

    helm install kchaos litmuschaos/kubernetes-chaos -n litmus

    kubectl -n litmus apply -f 3rd-party-values/litmus-test-app.yaml
    kubectl -n litmus apply -f 3rd-party-values/litmus-test.yaml

}