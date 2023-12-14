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