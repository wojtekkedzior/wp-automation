#!/bin/bash

# deprecated.  I've moved over to v3, but keeping this for reference.
function pulsar292() {
    kubectl apply -f kube-state-metrics-configs//kube-state-metrics-configs/
    kubectl apply -f node-exporter/kubernetes-node-exporter/

    helm upgrade --install pulsar apache/pulsar \
                 --values=pulsar-single/bookies.yaml \
                 --values=pulsar-single/broker.yaml \
                 --values=pulsar-single/proxy.yaml \
                 --values=pulsar-single/toolset.yaml \
                 --values=pulsar-single/values.yaml \
                 --timeout 10m \
                 --set initilize=true \
                 --version=2.9.2

    # Update the HA proxy with the ClusterIPs
    sleep 5
    sudo sed -i "/setenv GRAFANA_IP/c\\\tsetenv GRAFANA_IP $(kubectl get svc primary-grafana -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo sed -i "/setenv PROXY_IP/c\\\tsetenv PROXY_IP $(kubectl get svc primary-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo service haproxy restart

    # Enable node metrics in the pulasr grafana
    kubectl get configmap primary-prometheus -o yaml > temp-prom-cf.yaml
    sed -i '7i \    \- job_name: '\''nodes'\''' temp-prom-cf.yaml
    sed -i '8i \      \static_configs:' temp-prom-cf.yaml
    sed -i "9i \      \- targets: ['$(kubectl get svc node-exporter-prometheus-node-exporter -o json | jq -r '.spec.clusterIP'):9100']" temp-prom-cf.yaml
    kubectl apply -f temp-prom-cf.yaml
    rm temp-prom-cf.yaml
    kubectl delete pod --selector=component=prometheus

    sudo service haproxy restart

    while [ $(kubectl get po primary-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "not ready"
      sleep 1
    done

    echo "proxy is up"
    bash -c "source pulsar-setup.sh; singleCluster"
}