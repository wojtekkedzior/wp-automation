#/bin/bash

function startWorker() {
    host=$1
    joinCmd=$(tail -2 initout.txt)

    echo w | ssh -tt "w@${host}" 'yes | sudo kubeadm reset'
    echo w | ssh -tt "w@${host}" 'sudo rm -R /etc/cni/net.d'
#   This is not set on the workers. (? why not?)
#   ssh "w@${host}" 'rm .kube/config'
    echo w | ssh -tt "w@${host}" "sudo ${joinCmd}"
    echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks /mnt/fast-disks/disk1 /mnt/fast-disks/disk2 /mnt/fast-disks/disk3"

    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk1"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk2"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk3"

    echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=1G tmpfs /mnt/fast-disks/disk2"
    echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=1G tmpfs /mnt/fast-disks/disk3"

    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sdb"

    echo w | ssh -tt "w@${host}" "sudo mount /dev/sdb /mnt/fast-disks/disk1"
}

yes | sudo kubeadm reset
sudo rm -R /etc/cni/net.d
rm .kube/config

sudo kubeadm init --pod-network-cidr=192.168.122.0/18 | tee initout.txt

sudo cp -i /etc/kubernetes/admin.conf /home/w/.kube/config
#sudo chown w:w /home/w/.kube/config
sudo chown $(id -u):$(id -g) /home/w/.kube/config

#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#kubectl apply -f custom-resources.yaml

# install local volume provisioner
#kubectl create -f  local-volume-provisioner.generated.yaml

# install pulsar
#helm upgrade --install pulsar apache/pulsar   --values=values.yaml  --timeout 10m     --set initialize=true

#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c /pulsar/bin/pulsar-admin tenants create wojtekt
#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c /pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns
#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c /pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/wojtektopic -p 1

#ssh-keygen -t rsa -b 2048
#echo w | ssh-copy-id w@192.168.122.19
#echo w | ssh-copy-id w@192.168.122.74

#kubectl apply -f calico.yaml 
#kubectl create -f  local-volume-provisioner.generated.yaml
#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl apply -f kube-state-metrics-configs//kube-state-metrics-configs/
kubectl apply -f node-exporter/kubernetes-node-exporter/

# use a calico version from around Jan 22 because later versions change the PDB api from v1beta to v1
kubectl create -f https://docs.projectcalico.org/archive/v3.15/manifests/tigera-operator.yaml
#kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl apply -f custom-resources.yaml

#worker-4-large
startWorker 192.168.122.67

#worker-1-large
startWorker 192.168.122.74

#worker-2-large
startWorker 192.168.122.19

#worker-3-large
startWorker 192.168.122.72

#install local volume provisioner
kubectl create -f  local-volume-provisioner.generated.yaml

#after a PC restart you need to add callido
#curl https://docs.projectcalico.org/manifests/calico-typha.yaml -o calico.yaml
#k apply -f calico.yaml 

sleep 60

#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.2.0/deploy/static/provider/baremetal/deploy.yaml
#istio 
#kubectl create namespace istio-system
#helm install istio-base istio/base -n istio-system
#helm install istiod istio/istiod -n istio-system --wait

#kubectl create namespace istio-ingress
#kubectl label namespace istio-ingress istio-injection=enabled
#helm install istio-ingress istio/gateway -n istio-ingress --wait


#install pulsar 2.7.2
#helm upgrade --install pulsar apache/pulsar --values=values.yaml --timeout 10m --set initialize=true

#install pulsar 2.9.2
helm upgrade --install pulsar apache/pulsar --values=new-values.yaml --timeout 10m --set initialize=true

#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin tenants create wojtekt"
#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin namespaces create wojtekt/wojtekns"
#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-admin topics create-partitioned-topic wojtekt/wojtekns/wojtektopic -p 1"
#kubectl  exec -i pulsar-toolset-0  -- /bin/bash -c "/pulsar/bin/pulsar-perf produce persistent://wojtekt/wojtekns/wojtektopic --rate 5000 --size 5120 --test-duration 15"

#/pulsar/bin/pulsar-perf produce persistent://wojtekt/wojtekns/wojtektopic --rate 30000 --size 65536
#/pulsar/bin/pulsar-perf consume persistent://wojtekt/wojtekns/wojtektopic
