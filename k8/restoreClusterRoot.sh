#!/bin/bash

source pulsar3/setup/pulsar.sh
source third-party-tools.sh

# this will create mount points for up to 8 disks which are provided to virt-install.
function generateDiskMountCommands() {
    for n in $(seq 1 8); do
        disk="/dev/disk/by-id/virtio-${hostname}-$n"
        mountpoint="/mnt/fast-disks/disk$n"

        echo "mkdir -p $mountpoint && blkid $disk && mkfs.ext4 -F $disk"
        echo "echo $disk $mountpoint ext4 defaults 0 0 | sudo tee -a /etc/fstab"
    done
}

function createVmData() {
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
$(generateDiskMountCommands "$hostname" | sed 's/^/    /')

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
}

function createWorker() {
    hostname=$1

    createVmData $hostname

    sudo qemu-img create \
         -f qcow2 \
         -F qcow2 \
         -b /mnt/e1/worker-base.qcow2 \
         /mnt/e1/${hostname}.qcow2

    sudo cloud-localds \
         /mnt/e1/worker-iso/${hostname}-seed.iso \
         temp/user-data-${hostname}.yaml \
         temp/meta-data-${hostname}.yaml

    virt-install \
    --name ${hostname} \
    --memory 20000 \
    --vcpus 6 \
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
}

function createRemoteWorker() {
  hostname=$1

  createVmData $hostname

  scp temp/user-data-${hostname}.yaml wojtek@192.168.1.17:/mnt/workers
  scp temp/meta-data-${hostname}.yaml wojtek@192.168.1.17:/mnt/workers

  echo w | ssh -tt "wojtek@192.168.1.17" "sudo qemu-img create -f qcow2 -F qcow2 -b /mnt/storage/wojtek/vms/worker-base.qcow2 /mnt/workers/${hostname}.qcow2"
  echo w | ssh -tt "wojtek@192.168.1.17" "sudo cloud-localds /mnt/workers/worker-iso/${hostname}-seed.iso /mnt/workers/user-data-${hostname}.yaml /mnt/workers/meta-data-${hostname}.yaml"

  disk_args=""
  for n in $(seq 1 2); do
    disk_args+=" --disk path=/mnt/workers/${hostname}-${n}.qcow2,format=qcow2,bus=virtio,serial=${hostname}-${n}"
  done

  # echo w | ssh -tt "wojtek@192.168.1.17" "sudo virt-install --name ${hostname} --memory 10000 --vcpus 5 --cpu host --disk path=/mnt/workers/${hostname}.qcow2,format=qcow2,bus=virtio --disk path=/mnt/workers/worker-iso/${hostname}-seed.iso,device=cdrom ${disk_args} --network bridge=br0,model=virtio --os-variant ubuntu24.04 --graphics none --console pty,target_type=serial --import --noautoconsole"

  cmd="sudo virt-install \
      --name ${hostname} \
      --memory 10000 \
      --vcpus 5 \
      --cpu host \
      --disk path=/mnt/workers/${hostname}.qcow2,format=qcow2,bus=virtio \
      --disk path=/mnt/workers/worker-iso/${hostname}-seed.iso,device=cdrom \
      ${disk_args} \
      --network bridge=br0,model=virtio --os-variant ubuntu24.04 \
      --graphics none \
      --console pty,target_type=serial \
      --import --noautoconsole"

  echo w | ssh -tt "wojtek@192.168.1.17" "$cmd"
}

function cleanupClusterWorkers() {
    local workers=( "$@" )

    for n in "${workers[@]}"; do
        echo "worker-$n"
        virsh destroy "worker-$n"
        virsh undefine "worker-$n"

        echo w | ssh -tt "wojtek@192.168.1.17" "sudo virsh destroy remote-worker-$n"
        echo w | ssh -tt "wojtek@192.168.1.17" "sudo virsh undefine remote-worker-$n"
    done
}

function createCluster() {
    controlPlane=192.168.1.34

    ssh -tt "w@${controlPlane}" "sudo kubeadm reset -f"
    ssh -tt "w@${controlPlane}" "sudo rm -rf /etc/cni /opt/cni /var/lib/cni"
    ssh -tt "w@${controlPlane}" "sudo sudo systemctl restart containerd kubelet"
    ssh -tt "w@${controlPlane}" "sudo kubeadm init --pod-network-cidr=10.244.0.0/16 | tee initout.txt"

    # wait for cluster init
    sleep 6
    ssh "w@${controlPlane}" "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
    kubectl create -f cluster/tigera-operator.yaml

    # need a delay so that the tigera operator gets fully deployed. Maybe there is a way to dynamically wait for this?
    sleep 6
    kubectl create -f cluster/tigera-install.yaml

    ssh "w@${controlPlane}" "sudo cat initout.txt"  > temp/initout.txt # no -tt to capture the output
    join_cmd=$(grep -A 2 "kubeadm join" temp/initout.txt | sed 's/\\//g' | tr '\n' ' ' | xargs)
}

function k8() {
    workers=( "1-135" "2-135" "3-135" "4-135" )
    cleanupClusterWorkers "${workers[@]}"

    createCluster

    sudo rm /mnt/e1/worker-iso/worker-*-seed.iso temp/user-data-worker*.yaml temp/meta-data*.yaml

    for n in "${workers[@]}"; do
        createWorker "worker-$n" >> out-log-$n 2>&1 &
        createRemoteWorker "remote-worker-$n" >> out-log-remote-$n 2>&1 &
    done

    # there is no point in waiting for PIDs now that the VMs are getting created on the fly. This is because the scripts execute and return quickly, while the VMs start in the background.
    sleep 30

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
    echo "cleaning up pulsar"
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
