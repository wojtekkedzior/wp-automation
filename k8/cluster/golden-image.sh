
ssh-copy-id -i .ssh/k8_id_rsa.pub w@192.168.1.34

sudo apt install net-tools


w@control-place-135:~$ cat /etc/netplan/network.yaml 
network:
  ethernets:
    enp1s0:
      dhcp4: true
      nameservers:
        addresses:
        - 192.168.1.17
  version: 2




wget https://github.com/containerd/containerd/releases/download/v2.2.1/containerd-2.2.1-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-2.2.1-linux-amd64.tar.gz 

wget https://github.com/containernetworking/plugins/releases/download/v1.9.0/cni-plugins-linux-amd64-v1.9.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.9.0.tgz

sudo mkdir /usr/local/lib/systemd
sudo mkdir /usr/local/lib/systemd/system
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service 
sudo mv containerd.service /usr/local/lib/systemd/system/containerd.service
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl restart containerd

wget https://github.com/opencontainers/runc/releases/download/v1.4.0/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

sudo mkdir /etc/containerd/
containerd config default > config.toml
sudo mv config.toml /etc/containerd/

IMPORTANT:

Containerd versions 2.x:

[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  ...
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
    SystemdCgroup = true

sudo systemcl restart containerd

# kube adm
sudo apt install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list
  
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo apt upgrade -y

sudo systemctl enable kubelet

# swap and iptables
sudo swapoff -a

sudo tee /etc/modules-load.d/k8s.conf <<EOF
br_netfilter
EOF

sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# to verify 
lsmod | grep br_netfilter
# should look like:
# br_netfilter           32768  0
# bridge                421888  1 br_netfilter

mkdir -p /home/w/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/w/.kube/config
sudo chown w:w /home/w/.kube/config


# to make user 'w' not need a password over ssh after I user ssh-copy-key
sudo visudo
w ALL=(ALL) NOPASSWD:ALL



# It's super important to sanitise the baseimage after booting into it make changes
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo rm -f /etc/ssh/ssh_host_*
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
sudo rm -rf /var/log/journal/*
history -c
sudo rm -f /root/.bash_history