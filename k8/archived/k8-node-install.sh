ssh-copy-id -i ~/.ssh/id_rsa w@192.168.122.67

sudo apt install net-tools

# remove swap
# sudo vi /etc/fstab

sudo apt-get install -y apt-transport-https ca-certificates curl

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf br_netfilter
br_netfilter
EOF

@worker-4-large:~$ cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
> net.bridge.bridge-nf-call-ip6tables = 1
> et.bridge.bridge-nf-call-iptables = 1
> EOF

cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
> net.bridge.bridge-nf-call-iptables  = 1
> net.ipv4.ip_forward                 = 1
> net.bridge.bridge-nf-call-ip6tables = 1
> EOF


sudo sysctl --system

sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo groupadd docker
udo usermod -aG docker $USER
newgrp docker
systemctl enable docker.service


sudo apt install kubelet=1.20.4-00 kubeadm=1.20.4-00 kubectl=1.20.4-00 docker.io


sudo vi /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}

sudo systemctl restart docker

