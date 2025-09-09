#!/bin/bash

# Assumes the following:
# - machine with single disk
# - /etc/network/interfaces and /etc/hosts are configured prior to running this script
# join command must be run manually after this script

K8S_VERSION="1.34.0"

echo "[1/6] Systeem updaten..."
sudo apt update && sudo apt upgrade -y

sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[2/6] Vereiste pakketten installeren..."
sudo apt install -y apt-transport-https ca-certificates curl gpg htop

echo "[3/6] Containerd installeren en configureren..."
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "[4/6] Kubernetes $K8S_VERSION repo toevoegen en installeren..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/kubernetes.gpg
echo "deb [signed-by=/etc/apt/trusted.gpg.d/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[5/6] Sysctl-instellingen toepassen..."
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/br_netfilter.conf
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

echo "[6/6] CNI plugins installeren naar /usr/lib/cni..."
CNI_VERSION="v1.5.1"
ARCH="amd64"
sudo mkdir -p /opt/cni/bin
sudo mkdir -p /usr/lib/cni
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz" | sudo tar -C /opt/cni/bin -xz
