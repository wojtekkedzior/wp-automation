#/bin/bash

source setup/pulsar.sh
source setup/tools.sh

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

function k8() {
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
}

for values in $(echo "$@")
do
  # echo "Parameter values: "$values
  case "$values" in
  as )
    echo "Installing Auto-scalers"
    vpa && hpa
    ;;
  hz )
    echo "Installing hazelcast"
    hazelcast
    ;;
  istio )
    echo "Installing Istio"
    ;;
  k8 )
    echo "Installing k8 cluster"
    k8 
    ;;  
  sc )
    echo "Installing a single cluster"
    k8 && pulsarMonitoring && singleCluster
    ;;
  mc | deploy)
    echo "Installing multi cluster"
    k8 && pulsarMonitoring && multiCluster
    ;;
  pulsar-cleanup )
    echo "cleaing up pulsar"
    #TODO add helm uninstall
    kubectl delete pvc --all
    ;;
  help)
    help
    ;;
  *)
    echo "Not installing anything else"
    ;;
  esac
done