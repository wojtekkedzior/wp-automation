#/bin/bash

function startWorker() {
    host=$1
    joinCmd=$(tail -2 initout.txt)

    echo w | ssh -tt "w@${host}" 'yes | sudo kubeadm reset'
    echo w | ssh -tt "w@${host}" 'sudo rm -R /etc/cni/net.d'
#   This is not set on the workers. (? why not?)
#   ssh "w@${host}" 'rm .kube/config'
    echo w | ssh -tt "w@${host}" "sudo ${joinCmd}"
    echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks /mnt/fast-disks/disk1 /mnt/fast-disks/disk2 /mnt/fast-disks/disk3 /mnt/fast-disks/disk4 /mnt/fast-disks/disk5 /mnt/fast-disks/disk6 /mnt/fast-disks/disk7 /mnt/fast-disks/disk8"

    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk1"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk2"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk3"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk4"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk5"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk6"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk7"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk8"

    # tmpfs
    #echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk2"
    #echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk3"

    # normal (ext4) volumes 
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdb && sudo mount /dev/sdb /mnt/fast-disks/disk1"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdc && sudo mount /dev/sdc /mnt/fast-disks/disk2"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdd && sudo mount /dev/sdd /mnt/fast-disks/disk3"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sde && sudo mount /dev/sde /mnt/fast-disks/disk4"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdf && sudo mount /dev/sdf /mnt/fast-disks/disk5"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdg && sudo mount /dev/sdg /mnt/fast-disks/disk6"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdh && sudo mount /dev/sdh /mnt/fast-disks/disk7"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdi && sudo mount /dev/sdi /mnt/fast-disks/disk8"

    #in case we need to clean out some customer iamges
#    ssh -tt "w@${host}" "yes | docker system prune --all"
}

function pulsar292() {
    #install pulsar 2.9.2
    #helm upgrade --install pulsar apache/pulsar --values=new-values.yaml --timeout 10m --set initialize=true
#   helm upgrade --install pulsar apache/pulsar --values=new-values.yaml --timeout 10m --set initialize=true --version=2.9.2

    kubectl apply -f kube-state-metrics-configs//kube-state-metrics-configs/
    kubectl apply -f node-exporter/kubernetes-node-exporter/

    helm upgrade --install pulsar apache/pulsar \
    --values=pulsar/bookies.yaml \
    --values=pulsar/broker.yaml \
    --values=pulsar/proxy.yaml \
    --values=pulsar/toolset.yaml \
    --values=pulsar/values.yaml \
    --timeout 10m \
    --set initilize=true \
    --version=2.9.2

    # add charts https://github.com/apache/pulsar-helm-chart

    # Update the HA proxy with the ClusterIPs
    sleep 5
    sudo sed -i "/setenv GRAFANA_IP/c\\\tsetenv GRAFANA_IP $(kubectl get svc pulsar-grafana -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo sed -i "/setenv PROXY_IP/c\\\tsetenv PROXY_IP $(kubectl get svc pulsar-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo service haproxy restart

    # Enable node metrics in the pulasr grafana
    kubectl get configmap pulsar-prometheus -o yaml > temp-prom-cf.yaml
    sed -i '7i \    \- job_name: '\''nodes'\''' temp-prom-cf.yaml
    sed -i '8i \      \static_configs:' temp-prom-cf.yaml
    sed -i "9i \      \- targets: ['$(kubectl get svc node-exporter-prometheus-node-exporter -o json | jq -r '.spec.clusterIP'):9100']" temp-prom-cf.yaml
    kubectl apply -f temp-prom-cf.yaml
    rm temp-prom-cf.yaml
    kubectl delete pod --selector=component=prometheus

    sudo service haproxy restart

    while [ $(kubectl get po pulsar-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "not ready"
      sleep 5
    done

    echo "proxy is up"

    bash -c "source pulsar-setup.sh; singleCluster"
}

function pulsar210() {
    helm upgrade --install prometheus  prometheus-community/kube-prometheus-stack --version=50.3.0 --values prom-values.yaml
    
    echo "Installing pulsar 2.10"	
    #helm upgrade --install pulsar apache/pulsar --values=210values.yaml --timeout 10m --set initialize=true --version=3.0.0
    helm upgrade --install pulsar /home/w/wp-automation/k8/pulsar3/pulsar-helm-chart/charts/pulsar --version=3.0.0 --values=/home/w/wp-automation/k8/pulsar3/pulsar-helm-chart/charts/pulsar/values.yaml

    #add charts https://github.com/apache/pulsar-helm-chart
    # streamnative/apache-pulsar-grafana-dashboard-k8s

    sleep 5

    sudo sed -i "/setenv GRAFANA_IP/c\\\tsetenv GRAFANA_IP $(kubectl get svc prometheus-grafana -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo sed -i "/setenv PROXY_IP/c\\\tsetenv PROXY_IP $(kubectl get svc pulsar-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    sudo service haproxy restart
}


function multiCluster() {
    helm upgrade --install prometheus  prometheus-community/kube-prometheus-stack --version=47.6.1 --values ~/prom-values.yaml
    
    helm upgrade --install my-zookeeper bitnami/zookeeper  --values zk-values.yaml

    #helm repo add bitnami https://charts.bitnami.com/bitnami
    helm upgrade --install plite1 apache/pulsar \
    --values=pulsar-mc/plite1-values.yaml\
    --timeout 10m \
    --set initilize=true \
    --version=2.9.2

    # Update the HA proxy with the ClusterIPs
    sleep 5
    sudo sed -i "/setenv GRAFANA_IP/c\\\tsetenv GRAFANA_IP $(kubectl get svc plite1-pulsar-grafana -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
    sudo sed -i "/setenv PROXY_IP/c\\\tsetenv PROXY_IP $(kubectl get svc plite1-pulsar-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    # Enable node metrics in the pulasr grafana
    kubectl get configmap plite1-pulsar-prometheus -o yaml > temp-prom-cf.yaml
    sed -i '7i \    \- job_name: '\''nodes'\''' temp-prom-cf.yaml
    sed -i '8i \      \static_configs:' temp-prom-cf.yaml
    sed -i "9i \      \- targets: ['$(kubectl get svc prometheus-prometheus-node-exporter -o json | jq -r '.spec.clusterIP'):9100']" temp-prom-cf.yaml
    kubectl apply -f temp-prom-cf.yaml
    rm temp-prom-cf.yaml
    kubectl delete pod --selector=component=prometheus

    # ====================== plite2==============
    # ===========================================
    helm upgrade --install plite2 apache/pulsar \
    --values=pulsar-mc/plite2-values.yaml\
    --timeout 10m \
    --set initilize=true \
    --version=2.9.2

    # Update the HA proxy with the ClusterIPs
    sleep 5
    sudo sed -i "/setenv PROXY_IP_2/c\\\tsetenv PROXY_IP_2 $(kubectl get svc plite2-pulsar-proxy -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg

    sudo service haproxy restart

    while [ $(kubectl get po plite2-pulsar-proxy-0 -o json | jq -r .status.phase) != "Running" ];
    do
      echo "not ready"
      sleep 5
    done

    echo "proxy is up"

    bash -c "source pulsar-setup.sh; multiCluster"
}

function hazelcast() {
    #helm upgrade --install my-release hazelcast/hazelcast  --set cluster.memberCount=3
    helm upgrade --install my-release hazelcast/hazelcast -f hazelcast-values.yaml

    sleep 5
    sudo sed -i "/setenv HAZELCAST_IP/c\\\tsetenv HAZELCAST_IP $(kubectl get svc my-release-hazelcast -o json | jq -r '.spec.clusterIP')" /etc/haproxy/haproxy.cfg
}

yes | sudo kubeadm reset
sudo rm -R /etc/cni/net.d
rm /home/w/.kube/config

sudo kubeadm init --pod-network-cidr=192.168.122.0/18 | tee initout.txt

sudo cp -i /etc/kubernetes/admin.conf /home/w/.kube/config
#sudo chown w:w /home/w/.kube/config
sudo chown $(id -u):$(id -g) /home/w/.kube/config

#kubectl apply -f custom-resources.yaml

#ssh-keygen -t rsa -b 2048
#echo w | ssh-copy-id w@192.168.122.19
#echo w | ssh-copy-id w@192.168.122.74

#kubectl apply -f calico.yaml 
#kubectl create -f  local-volume-provisioner.generated.yaml
#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#kubectl apply -f kube-state-metrics-configs//kube-state-metrics-configs/
#kubectl apply -f node-exporter/kubernetes-node-exporter/
#helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

#helm install node-exporter prometheus-community/prometheus-node-exporter

# use a calico version from around Jan 22 because later versions change the PDB api from v1beta to v1
#kubectl create -f https://docs.projectcalico.org/archive/v3.15/manifests/tigera-operator.yaml
# I had to download this file and update the pod selector beucase the damnn thing was trying to deploy on the cp which results in evictions
kubectl apply -f tigera-operator.yaml
#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl apply -f calico-custom-resources.yaml

# Update the workers
startWorker 192.168.122.74 # worker-1-large
startWorker 192.168.122.19 # worker-2-large
startWorker 192.168.122.72 # worker-3-large
startWorker 192.168.122.67 # worker-4-large

#install local volume provisioner
kubectl create -f  local-volume-provisioner.generated.yaml

#helm upgrade --install prometheus  prometheus-community/kube-prometheus-stack --version=47.6.1 --values ~/prom-values.yaml 
# helm upgrade --install prometheus  prometheus-community/kube-prometheus-stack

#after a PC restart you need to add callico
#curl https://docs.projectcalico.org/manifests/calico-typha.yaml -o calico.yaml
#k apply -f calico.yaml 

#It takes a while for the local-volume-provisioner to find all the local volumes
sleep 10

#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.0/deploy/static/provider/baremetal/deploy.yaml
#istio 
#kubectl create namespace istio-system
#helm install istio-base istio/base -n istio-system
#helm install istiod istio/istiod -n istio-system --wait

#kubectl create namespace istio-ingress
#kubectl label namespace istio-ingress istio-injection=enabled
#helm install istio-ingress istio/gateway -n istio-ingress --wait

# install pulsar
pulsar210
#pulsar292

#multiCluster


#hazelcast


