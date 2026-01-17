#!/bin/bash

source pulsar3/setup/pulsar.sh
source third-party-tools.sh

pids=()

function generateDiskCommands() {
    for n in $(seq 1 8); do
        disk="/dev/disk/by-id/virtio-${hostname}-$n"
        mountpoint="/mnt/fast-disks/disk$n"

        echo "mkdir -p $mountpoint"
        echo "mkdir -p $mountpoint && blkid $disk || mkfs.ext4 -F $disk"
        echo "grep -q $mountpoint /etc/fstab || echo $disk $mountpoint ext4 defaults 0 0 >> /etc/fstab"
    done
}

function createWorker() {
    pids+=($BASHPID)

    hostname=$1

    cat > temp/user-data-${hostname}.yaml <<EOF
#cloud-config
hostname: ${hostname}
manage_etc_hosts: true

package_update: false
package_upgrade: false

write_files:
- path: /usr/local/bin/kubeadm-join.sh
  permissions: '0755'
  content: |
    #!/bin/bash
    set -eux
    ${join_cmd}

- path: /usr/local/bin/mount-fast-disks.sh
  permissions: '0755'
  content: |
$(generateDiskCommands "$hostname" | sed 's/^/    /')

runcmd:
  - swapoff -a
  - systemctl enable kubelet
  - /usr/local/bin/mount-fast-disks.sh
  - mount -a
  - /usr/local/bin/kubeadm-join.sh
EOF

    cat > temp/meta-data-${hostname}.yaml <<EOF
instance-id: ${hostname}
local-hostname: ${hostname}
EOF
    sudo qemu-img create \
    -f qcow2 \
    -F qcow2 \
    -b /mnt/e1/worker-base.qcow2 \
    /mnt/e1/${hostname}.qcow2

    sudo cloud-localds /mnt/e1/worker-iso/${hostname}-seed.iso temp/user-data-${hostname}.yaml temp/meta-data-${hostname}.yaml

    virt-install \
    --name ${hostname} \
    --memory 16384 \
    --vcpus 4 \
    --cpu host \
    --disk path=/mnt/e1/${hostname}.qcow2,format=qcow2,bus=virtio \
    --disk path=/mnt/e1/worker-iso/${hostname}-seed.iso,device=cdrom \
    $(for n in {1..8}; do
      echo --disk path=/mnt/k8volumes/${hostname}-$n.qcow2,format=qcow2,bus=virtio,serial=${hostname}-$n
      done) \
    --network bridge=br0,model=virtio \
    --os-variant ubuntu24.04 \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole

    sleep 10
}

function startRemoteWorker() {
    pids+=($BASHPID)
    workerAddress=$1

    echo w | ssh -tt "w@${workerAddress}" "sudo swapoff -a && sudo kubeadm reset -f && sudo rm -R /etc/cni/net.d"
    sleep 10
    echo w | ssh -tt "w@${workerAddress}" "sudo ${join_cmd}"
    sleep 10
    echo w | ssh -tt "w@${workerAddress}" "sudo umount -f /mnt/fast-disks/disk1 /mnt/fast-disks/disk2"
    echo w | ssh -tt "w@${workerAddress}" "sudo mkfs.ext4 -F /dev/sda && sudo mount /dev/sda /mnt/fast-disks/disk1"
    echo w | ssh -tt "w@${workerAddress}" "sudo mkfs.ext4 -F /dev/sdb && sudo mount /dev/sdb /mnt/fast-disks/disk2"

    # since these workers are created using this .iso image, then their cloud-init scripts will never run. Hence, we need to restart the containerd service
    echo w | ssh -tt "w@${workerAddress}" "sudo systemctl restart containerd"
}

function cleanupClusterWorkers() {
    local workers=( "$@" )

    for n in "${workers[@]}"; do
        echo "worker-$n"
        virsh destroy "worker-$n"
        virsh undefine "worker-$n"
    done
}

function createCluster() {
    controlPlane=192.168.1.34

    ssh -tt "w@${controlPlane}" "sudo kubeadm reset -f"
    ssh -tt "w@${controlPlane}" "sudo rm -rf /etc/cni /opt/cni /var/lib/cni"
    ssh -tt "w@${controlPlane}" "sudo sudo systemctl restart containerd kubelet"
    ssh -tt "w@${controlPlane}" "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee initout.txt"

    # wait for cluster intit
    sleep 6
    ssh "w@${controlPlane}" "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
    kubectl create -f cluster/tigera-operator.yaml

    # need a delay so that the tigera operator gets fully deployed. Maybe there is a way to dynamically wait for this?
    sleep 6
    kubectl create -f cluster/tigera-install.yaml

    ssh "w@${controlPlane}" "sudo cat initout.txt"  > initout.txt # no -tt to capture the output
    join_cmd=$(grep -A 2 "kubeadm join" initout.txt | sed 's/\\//g' | tr '\n' ' ' | xargs)

    # sleep 5
}

# sometimes I need to attach very large volumes to a handful of workers. Here I can do that without making the automation way to complicated
function attachExtraStorage() {
    echo "attaching extra storage"

#   index=1
#   echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks"
#   for disk in {a..k}
#   do
#     echo w | ssh -tt "w@${host}" "sudo mkdir /mnt/fast-disks/disk${index}"
#     echo w | ssh -tt "w@${host}" "sudo umount -f /mnt/fast-disks/disk${index}"
#     echo w | ssh -tt "w@${host}" "yes | sudo mkfs.ext4 /dev/sd${disk} && sudo mount /dev/sd${disk} /mnt/fast-disks/disk${index}"
#     (( index++ ))
#   done
}

function k8() {
    workers=( "1-135" "2-135" "3-135" "4-135" )

    cleanupClusterWorkers "${workers[@]}"

    createCluster

    sudo rm /mnt/e1/worker-iso/worker-*-seed.iso temp/user-data-worker*.yaml temp/meta-data*.yaml

    for n in "${workers[@]}"; do
        createWorker "worker-$n" &
    done

    # not creating the remote workers on the fly as the server is quite slow. Reusing VMs created from the same base image as the VMs running on localhost.
    time startRemoteWorker 192.168.1.131 >> temp/out-log-1 2>&1 &
    time startRemoteWorker 192.168.1.132 >> temp/out-log-2 2>&1 &

    wait "${pids[@]}" && echo "All workers are up"

    attachExtraStorage

    kubectl create -f cluster/local-volume-provisioner.generated.yaml

    kubectl create -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
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
  litmus )
    echo "Installing litmus"
    litmus
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
