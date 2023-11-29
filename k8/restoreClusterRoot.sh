#/bin/bash

function startWorker() {
    workerId=$1
    host=$2
    joinCmd=$(tail -2 initout.txt)

    echo w | ssh -tt "w@${host}" 'yes | sudo kubeadm reset'
    echo w | ssh -tt "w@${host}" 'sudo rm -R /etc/cni/net.d'
#   This is not set on the workers. (? why not?)
#   ssh "w@${host}" 'rm .kube/config'
    echo w | ssh -tt "w@${host}" "sudo ${joinCmd}"

    # prepare mount dirs, unmount if already mounted, format and (re)mount
    index=1
    echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks"
    for disk in {b..p}
    do
        echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks/disk${index}"
        echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk${index}"
        echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sd${disk} && sudo mount /dev/sd${disk} /mnt/fast-disks/disk${index}"
        (( index++ ))
    done

    # tmpfs
    # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk2"
    # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk3"

    # in case we need to clean out some customer iamges
    # echo w | ssh -tt "w@${host}" "yes | sudo docker system prune --all"

    echo w | ssh -tt "w@${host}" "sudo systemctl restart containerd.service"

    echo 1 > out-$workerId
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

    sleep 10
    bash -c "source pulsar-setup.sh; singleCluster"
}

function multiCluster() {
    pulsar3mc

    # install a standalone version of zookeeper. This is known as the 'configurationStore' when it comes to working with geo-replication. Make sure to  change the client.port to something other than 2181 as that port is already used by the other zookeepers
    #helm repo add bitnami https://charts.bitnami.com/bitnami
    helm upgrade --install my-zookeeper bitnami/zookeeper --values zk-values.yaml

    # ------------------ plite2 ------------------
    helm upgrade --install backup apache/pulsar \
                 --values=pulsar-mc/plite2-values.yaml\
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
    bash -c "source pulsar-setup.sh; multiCluster"
}

function hazelcast() {
    helm upgrade --install my-release hazelcast/hazelcast -f hazelcast-values.yaml #--set cluster.memberCount=3
    sleep 2
    sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
}

# cascade the wait-for workers. The first loop will take the longs and the last 2 will be really quick as those two workers should be ready at about the same time as the first two.
function waitForWorkers() {
    for workerId in {1..4}
    do
        while [ ! -f "out-${workerId}" ]
        do
            echo "waiting for worker ${workerId}"
            sleep 3
        done
        echo "Worker ${workerId} is alive"
    done
}

yes | sudo kubeadm reset && 
sudo rm -R /etc/cni/net.d
rm /home/w/.kube/config
sudo kubeadm init --pod-network-cidr=192.168.122.0/18 | tee initout.txt
sudo cp -i /etc/kubernetes/admin.conf /home/w/.kube/config
sudo chown $(id -u):$(id -g) /home/w/.kube/config

sudo systemctl restart containerd.service 

# use a calico version from around Jan 22 because later versions change the PDB api from v1beta to v1
# kubectl apply -f tigera-operator.yaml
kubectl create -f new-tigera-operator.yaml
kubectl apply -f calico-custom-resources.yaml



# remove output from prior runs
rm out-[1-4] out-log-[1-4]

time startWorker 1 192.168.100.221 >> out-log-1 &   # worker-1-large
time startWorker 2 192.168.100.252 >> out-log-2 &   # worker-2-large
time startWorker 3 192.168.100.244 >> out-log-3 &   # worker-3-large
time startWorker 4 192.168.100.171 >> out-log-4 &   # worker-4-large

# block on checking whether the first worker is up. All the workers should come up at around the same time.
waitForWorkers

#install local volume provisioner and give it some time to start and identify the nodes' volumes
kubectl create -f local-volume-provisioner.generated.yaml

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --version=50.3.0 --values prom-values.yaml

kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type merge --patch='{ "spec":{ "podMonitorSelector":{ "matchLabels":{ "release": "primary"}}}}'
kubectl patch Prometheus prometheus-kube-prometheus-prometheus --type json  --patch='[{"op": "replace", "path": "/spec/logLevel", "value": "debug"}]'

# singleCluster or multiCluster or hazelcast
# TODO: need to add more params such as sc, mc, hz and by default install only k8
$1