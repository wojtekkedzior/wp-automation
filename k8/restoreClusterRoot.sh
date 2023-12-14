#/bin/bash

source pulsar-setup/pulsar.sh
source k8-cluster/third-party-tools.sh

function startWorker() {
  workerId=$1
  host=$2
  joinCmd=$(tail -2 initout.txt)

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
      echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sd${disk} && sudo mount /dev/sd${disk} /mnt/fast-disks/disk${index}"
      (( index++ ))
  done

  # tmpfs - in case a need some RAM drives
  # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk2"
  # echo w | ssh -tt "w@${host}" "sudo mount -t tmpfs -o rw,size=2G tmpfs /mnt/fast-disks/disk3"

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
        sleep 10
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

  # install the CNI - calico in this case
  kubectl create -f k8-cluster/tigera-operator.yaml 
  kubectl apply -f k8-cluster/tigera-install.yaml

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
  case "$values" in
  as )
    echo "Installing Auto-scalers"
    vpa && hpa
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