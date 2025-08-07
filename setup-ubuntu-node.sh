#!/bin/bash

# --- 1. SYSTEM PREPARATION ---

# Disable swap memory. This is a requirement for the kubelet.
sudo swapoff -a
# And disable it permanently in the fstab file.
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load required kernel modules for container networking.
sudo modprobe overlay
sudo modprobe br_netfilter

# Create a sysctl config file for Kubernetes networking.
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply the sysctl parameters without a reboot.
sudo sysctl --system

# --- 2. INSTALL CONTAINERD RUNTIME ---

# Install containerd, which is a lightweight and standard container runtime.
sudo apt-get update
sudo apt-get install -y containerd

# Create a default configuration file for containerd.
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1

# Modify the containerd config to use the systemd cgroup driver, which is recommended for kubelet.
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart and enable the containerd service to apply changes.
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- 3. INSTALL KUBERNETES COMPONENTS (kubeadm, kubelet, kubectl) ---

# Update apt package index and install packages needed to use the Kubernetes apt repository.
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Download the public signing key for the new Kubernetes package repository.
# (The old k8s.gcr.io repository is deprecated).
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add the appropriate Kubernetes apt repository.
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update apt package index again with the new repo, then install kubelet, kubeadm, and kubectl.
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Pin the versions of the Kubernetes packages to prevent unwanted automatic upgrades.
sudo apt-mark hold kubelet kubeadm kubectl

echo "✅ Worker node setup is complete. Now, run the 'kubeadm join' command from your control-plane."
