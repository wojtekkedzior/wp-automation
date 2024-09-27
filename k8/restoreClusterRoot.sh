#!/bin/bash

source pulsar3/setup/pulsar.sh
source k8-cluster/third-party-tools.sh

pids=()

function startWorker() {
  workerId=$1
  host=$2
  joinCmd=$(tail -2 initout.txt)

  echo "worker one: $BASHPID"
  pids+=($BASHPID)

  echo w | ssh -tt "w@${host}" 'yes | sudo kubeadm reset'
  echo w | ssh -tt "w@${host}" 'sudo rm -R /etc/cni/net.d'
  echo w | ssh -tt "w@${host}" "sudo ${joinCmd}"

  # prepare mount dirs, unmount if already mounted, format and (re)mount
  index=1
  echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks"
  for disk in {b..p}
  do
    echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks/disk${index}"
    echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk${index}"
    echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/vd${disk} && sudo mount /dev/vd${disk} /mnt/fast-disks/disk${index}"
    (( index++ ))
  done

  # tmpfs - in case a need some RAM drives
  # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk2"
  # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk3"

  echo w | ssh -tt "w@${host}" "sudo systemctl restart containerd.service"
}

function k8() {
  yes | sudo kubeadm reset && 
  sudo rm -R /etc/cni/net.d
  rm /home/w/.kube/config
  sudo kubeadm init --pod-network-cidr=192.168.122.0/18 | tee initout.txt
  sudo cp -i /etc/kubernetes/admin.conf /home/w/.kube/config
  sudo chown $(id -u):$(id -g) /home/w/.kube/config

  sudo systemctl restart containerd.service

  # install the CNI - calico in this case
  kubectl create -f k8-cluster/tigera-operator.yaml 
  kubectl apply -f k8-cluster/tigera-install.yaml

  # remove output from prior runs
  rm out-log-[1-4]

# old server
  # time startWorker 1 192.168.100.221 > out-log-1 2>&1 &
  # time startWorker 2 192.168.100.252 > out-log-2 2>&1 &
  # time startWorker 3 192.168.100.244 > out-log-3 2>&1 &
  # time startWorker 4 192.168.100.171 > out-log-4 2>&1 &

  time startWorker 1 192.168.122.11 > out-log-1 2>&1 &
  time startWorker 2 192.168.122.12 > out-log-2 2>&1 &
  time startWorker 3 192.168.122.13 > out-log-3 2>&1 &
  time startWorker 4 192.168.122.14 > out-log-4 2>&1 &

  # block on checking whether the first worker is up. All the workers should come up at around the same time.
  wait "${pids[@]}"
}

for values in $(echo "$@")
do
  case "$values" in
  as )
    echo "Installing Auto-scalers"
    vpa && hpa
    ;;
  cb )
    echo "Installing CouchBase"
    couchBase
    ;;
  hc )
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
  mc )
    echo "Installing multi cluster"
    k8 && pulsarMonitoring && multiCluster
    ;;
  ng )
    echo "Installing nginx"
    nginx
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