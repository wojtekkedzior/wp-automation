#!/bin/bash

pollInterval=10

function pulsarMonitoring() {
    #install local volume provisioner and give it some time to start and identify the nodes' volumes

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --version=50.3.0 --values pulsar3/setup/prom-values.yaml || exit 1

    kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type merge --patch='{ "spec":{ "podMonitorSelector":{ "matchLabels":{ "release": "primary"}}}}'
    kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type json  --patch='[{"op": "replace", "path": "/spec/logLevel", "value": "debug"}]'
}

function singleCluster() {
    # Randomly selected worker 3 to load grafana dashboards
    workerIp=$(kubectl get nodes --field-selector metadata.name=worker-3-135 -o json | jq -r '.items[0].status.addresses[0].address')

    helm upgrade --install primary pulsar3/charts/pulsar \
                 --values=pulsar3/charts/pulsar/bookies.yaml \
                 --values=pulsar3/charts/pulsar/broker.yaml \
                 --values=pulsar3/charts/pulsar/proxy.yaml \
                 --values=pulsar3/charts/pulsar/toolset.yaml \
                 --values=pulsar3/charts/pulsar/values.yaml \
                 --timeout 10m \
                 --set initilize=true \
                 --version=3.0.0 || exit 1

    # the metrics for the brokers and proxies is at /metrics/cluster=<cluster-name>
    kubectl patch podmonitor primary-broker --type json --patch='[{"op": "replace", "path": "/spec/podMetricsEndpoints/0/path", "value": "/metrics/cluster=primary"}]'
    kubectl patch podmonitor primary-proxy  --type json --patch='[{"op": "replace", "path": "/spec/podMetricsEndpoints/0/path", "value": "/metrics/cluster=primary"}]'

    #add charts https://github.com/apache/pulsar-helm-chart
    # streamnative/apache-pulsar-grafana-dashboard-k8s

    creds="admin:prom-operator"

    # grafana's svc defaults to ClusterIP, which needs to be changed to NodePort on port 30003
    kubectl patch svc prometheus-grafana -p '{"spec": {"type": "NodePort", "ports": [{"name": "http-web", "port": 80, "protocol": "TCP", "targetPort": 3000, "nodePort": 30003}]}}'

    # The initial call to the health check will fail as grafana takes a wee-while to get started.
    # Once its "status.phase" = Running, it's still not ready for the api invocation hence we wait for the healthcheck to be up before uploading the dashboards
    gr=1
    while [ ${gr} != 0 ];
    do 
        curl -s -u ${creds} http://${workerIp}:30003/api/health --connect-timeout 5
        gr=$?
    done

    echo "grafana is ready. proceeding to import dashboards"

    # now upload all of our dashboards
    for filename in dashboards/ds/*.json; do
        curl -X POST -u ${creds} -H "Content-Type: application/json" -d @${filename} http://${workerIp}:30003/api/dashboards/import
    done;

    echo "dashboards imported"

    while [ "$(curl -s http://${workerIp}:30001/status.html)" != "OK" ];
    do
        echo "proxy not ready. waiting..."
        sleep ${pollInterval}
    done;

    bash -c "source pulsar3/setup/cluster-setup.sh; singleCluster"
}

function multiCluster() {
    singleCluster

    # install a standalone version of zookeeper. This is known as the 'configurationStore' when it comes to working with geo-replication. Make sure to  change the client.port to something other than 2181 as that port is already used by the other zookeepers
    #helm repo add bitnami https://charts.bitnami.com/bitnami
    helm upgrade --install my-zookeeper bitnami/zookeeper --values pulsar3/setup/zk-values.yaml

    # ------------------ plite2 ------------------
    helm upgrade --install backup apache/pulsar \
                 --values=pulsar3-mc/plite2-values.yaml\
                 --timeout 10m \
                 --set initilize=true \
                 --version=3.0.0 || exit 1

    # with two clusters, we need to wait for the second proxie to come up so that we can create resources on the back up cluster
    while [ $(kubectl get po backup-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "backup proxy not ready. waiting..."
      sleep ${pollInterval}
    done
    bash -c "source  pulsar3/setup/cluster-setup.sh; multiCluster"
}