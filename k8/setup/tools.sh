#!/bin/bash

function istio() {
    echo "TODO"
    #TODO
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
    
    helm upgrade --install my-release hazelcast/hazelcast -f hazelcast-values.yaml #--set cluster.memberCount=3
    sleep 2
    sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
}