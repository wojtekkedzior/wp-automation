#!/bin/bash

function pulsarMonitoring() {
    #install local volume provisioner and give it some time to start and identify the nodes' volumes
    kubectl create -f local-volume-provisioner.generated.yaml

    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --version=50.3.0 --values prom-values.yaml

    kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type merge --patch='{ "spec":{ "podMonitorSelector":{ "matchLabels":{ "release": "primary"}}}}'
    kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type json  --patch='[{"op": "replace", "path": "/spec/logLevel", "value": "debug"}]'
}

function pulsar3mc() {
    helm upgrade --install primary pulsar3/charts/pulsar \
                 --values=pulsar3/charts/pulsar/mc-bookies.yaml \
                 --values=pulsar3/charts/pulsar/mc-broker.yaml \
                 --values=pulsar3/charts/pulsar/mc-proxy.yaml \
                 --values=pulsar3/charts/pulsar/toolset.yaml \
                 --values=pulsar3/charts/pulsar/values.yaml \
                 --timeout 10m \
                 --set initilize=true \
                 --version=3.0.0
    pulsar3Config
}

function pulsar3() {
    helm upgrade --install primary pulsar3/charts/pulsar \
                 --values=pulsar3/charts/pulsar/bookies.yaml \
                 --values=pulsar3/charts/pulsar/broker.yaml \
                 --values=pulsar3/charts/pulsar/proxy.yaml \
                 --values=pulsar3/charts/pulsar/toolset.yaml \
                 --values=pulsar3/charts/pulsar/values.yaml \
                 --timeout 10m \
                 --set initilize=true \
                 --version=3.0.0
    pulsar3Config
}

function pulsar3Config() {
    # the metrics for the brokers and proxies is at /metrics/cluster=<cluster-name>
    kubectl patch podmonitor primary-broker --type json --patch='[{"op": "replace", "path": "/spec/podMetricsEndpoints/0/path", "value": "/metrics/cluster=primary"}]'
    kubectl patch podmonitor primary-proxy  --type json --patch='[{"op": "replace", "path": "/spec/podMetricsEndpoints/0/path", "value": "/metrics/cluster=primary"}]'

    sudo sed -i "/setenv GRAFANA_IP/c\\\tsetenv GRAFANA_IP $(kubectl get svc prometheus-grafana -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo sed -i "/setenv PROXY_IP/c\\\tsetenv PROXY_IP $(kubectl get svc primary-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    sudo service haproxy restart

    #add charts https://github.com/apache/pulsar-helm-chart
    # streamnative/apache-pulsar-grafana-dashboard-k8s

    grafanaSvcIp=$(kubectl get svc prometheus-grafana -o json | jq -r '.spec.clusterIP')
    creds="admin:prom-operator"

    # The initial call to the health check will fail as grafana takes a wee-while to get started.
    # Once its "status.phase" = Running, it's still not ready for the api invocation hence we wait for the healthcheck to be up before uploading the dashboards
    gr=1
    while [ ${gr} != 0 ];
    do 
        curl -s -u ${creds} http://$grafanaSvcIp/api/health --connect-timeout 1
        gr=$?
    done

    # now upload all of our dashboards
    for filename in dashboards/ds/*.json; do
        curl -X POST -u ${creds} -H "Content-Type: application/json" -d @${filename} http://$grafanaSvcIp/api/dashboards/import
    done;
}

function singleCluster() {
    pulsar3

    while [ $(kubectl get po primary-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "proxy not ready. waiting..."
      sleep 5
    done

    while [ "$(curl -s http://$(kubectl get svc primary-proxy -o json | jq -r '.spec.clusterIP'):8080/status.html)" != "OK" ];
    do
        echo "proxy up, but not yet ready to work..."
        sleep 1
    done;

    bash -c "source ../pulsar-setup.sh; singleCluster"
}

function multiCluster() {
    pulsar3mc

    # install a standalone version of zookeeper. This is known as the 'configurationStore' when it comes to working with geo-replication. Make sure to  change the client.port to something other than 2181 as that port is already used by the other zookeepers
    #helm repo add bitnami https://charts.bitnami.com/bitnami
    helm upgrade --install my-zookeeper bitnami/zookeeper --values ../zk-values.yaml

    # ------------------ plite2 ------------------
    helm upgrade --install backup apache/pulsar \
                 --values=../pulsar-mc/plite2-values.yaml\
                 --timeout 10m \
                 --set initilize=true \
                 --version=3.0.0

    # Update the HA proxy with the ClusterIPs
    sudo sed -i "/setenv PROXY_2_IP/c\\\tsetenv PROXY_2_IP $(kubectl get svc backup-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    sudo service haproxy restart

    # with two clusters, we need to wait for the second proxie to come up so that we can create resources on the back up cluster
    while [ $(kubectl get po backup-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "proxy not ready. waiting..."
      sleep 5
    done
    bash -c "source ../pulsar-setup.sh; multiCluster"
}