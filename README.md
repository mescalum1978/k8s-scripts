# Kubernetes on Debian 13 with Cilium (Bare Metal / Proxmox Lab)

This repository contains installation scripts to deploy a minimal Kubernetes cluster on **Debian 13**, designed for **on-prem or Proxmox-based labs** using **commodity hardware**.
The focus is on infrastructure, networking, and maintainability — not on application deployment.

---

## 🧱 Architecture Overview

* **1 Control Plane (Master) Node**
* **1+ Worker Nodes**
* **Container Runtime:** containerd
* **CNI Plugin:** [Cilium](https://cilium.io)
* **Operating System:** Debian 13
* **Hardware Target:** Bare-metal or Proxmox VMs (virtio network interfaces)

---

## 🌐 Network Topology

Below is an example topology for a small lab setup:

```
                        +---------------------+
                        |     Management PC   |
                        | (kubectl, Git, etc.)|
                        +----------+----------+
                                   |
                                   | 192.168.1.0/24 (LAN)
                                   |
                   +---------------+----------------+
                   |                                |
          +--------+--------+              +--------+--------+
          |   Master Node   |              |   Worker Node   |
          |  192.168.1.31   |              |  192.168.1.32   |
          |-----------------|              |-----------------|
          | kube-apiserver  |              | kubelet          |
          | etcd            |              | containerd       |
          | containerd      |              | Cilium agent     |
          | Cilium agent    |              |------------------|
          +--------+--------+              +--------+--------+
                   |                                |
                   +---------------+----------------+
                                   |
                              Pod Network (10.244.0.0/16)
                                   |
                        +----------+----------+
                        |     Cilium Overlay  |
                        |     (eBPF-based)    |
                        +---------------------+
```

### Network details

* **LAN network:** Management and node access
* **Pod network:** Managed by Cilium (default: `10.244.0.0/16`)
* **Service network:** Managed by Kubernetes (default: `10.96.0.0/12`)
* **Communication:** Nodes talk directly over LAN; Cilium manages overlay routing and load balancing

---

## ⚙️ Prerequisites

* Debian 13 installed on each node
* Static IP and hostname configured (`/etc/network/interfaces`, `/etc/hosts`)
* Internet access to fetch packages and CNI binaries
* Swap disabled

---

## 🚀 Installation Steps

### 1. Master Node Setup

Run the **master setup script**:

```bash
sudo bash master-node-setup.sh
```

This script:

* Updates the system
* Installs and configures `containerd`
* Adds the Kubernetes 1.34 repo
* Configures sysctl and kernel modules
* Installs CNI plugins
* Initializes the cluster with `kubeadm`
* Deploys Cilium as the network layer

Once initialization is complete, the script outputs the `kubeadm join` command for worker nodes.

---

### 2. Worker Node Setup

Run the **worker setup script** (steps 1–7 of the master script):

```bash
sudo bash worker-node-setup.sh
```

Then join the cluster using the token displayed during master setup:

```bash
sudo kubeadm join <MASTER-IP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

---

## 🔍 Verification

Check node and pod status:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Confirm Cilium is active:

```bash
kubectl -n kube-system get pods -l k8s-app=cilium
```

---

## 🧰 Optional: Storage and Persistence

For bare-metal setups, it’s recommended to:

* Use a **boot mirror (RAID1)** for OS reliability
* Configure a **ZFS pool** for container and persistent volume storage
* Mount the ZFS pool under `/var/lib/containerd` or use it for dynamic PV provisioning

---

## 🧠 Notes

* This setup avoids a hypervisor layer to reduce complexity and overhead.
* Cilium replaces Flannel, providing observability, eBPF-based networking, and future scalability options (Hubble, Cilium Mesh).
* Scripts are designed to be reproducible and easy to modify for new Kubernetes releases.

---

## 📜 License

MIT License — feel free to reuse and adapt this setup for personal or educational projects.

---
