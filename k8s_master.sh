#!/bin/bash

# Assumes the following:
# - machine with single disk
# - /etc/network/interfaces and /etc/hosts are configured prior to running this script

K8S_VERSION="1.34.0"

echo "[1/7] Updating system, disable swap"
sudo apt update && sudo apt upgrade -y

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[2/7] Install prerequisite packages, htop is optional..."
sudo apt install -y apt-transport-https ca-certificates curl gpg htop

echo "[3/7] Install and configure containerd..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's|bin_dir = "/usr/lib/cni"|bin_dir = "/opt/cni/bin"|' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[4/7] Add Kubernetes $K8S_VERSION repo and install..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[5/7] Apply Sysctl settings..."
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "[6/7] Disable nftables (when active)..."
sudo systemctl stop nftables || true
sudo systemctl disable nftables || true

echo "[7/7] Install CNI plugins..."
CNI_VERSION="v1.5.1"
ARCH="amd64"
sudo mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | sudo tar -C /opt/cni/bin -xz

echo "[Master] Initializing Kubernetes cluster..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo "[Master] Configurere kubectl for current user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[Master] Deploy Flannel network..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
echo "Sleeping 10 sec to allow flannel plugins to be available prior to copying them to /usr/lib/cni. This is a workaround to allow coredns pods to be deployed successfully..."
sleep 10

echo "Optional commands post deployment..."
kubectl get nodes
kubectl get pods -n kube-system

echo "Display join command for worker node(s)..."
kubeadm token create --print-join-command
