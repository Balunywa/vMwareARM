

In MicroK8s, the kubeconfig file is typically located at the following path:

/var/snap/microk8s/current/credentials/client.config


export KUBECONFIG=/var/snap/microk8s/current/credentials/client.config
After setting the KUBECONFIG environment variable, you can use kubectl or other Kubernetes-related tools, and they will use the specified kubeconfig file for cluster access.

#!/bin/bash

set -e

# Function to log messages
log_msg() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to disable swap
disable_swap() {
    log_msg "Disabling swap..."
    swapoff -a
    sed -i -r 's/(\/swap.+)/#\1/' /etc/fstab
    log_msg "Swap disabled."
}

# Function to install Docker CE
install_docker() {
    log_msg "Installing Docker..."
    apt update
    apt upgrade -y
    apt install ca-certificates software-properties-common apt-transport-https curl -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install docker-ce docker-ce-cli containerd.io -y

    cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

    mkdir -p /etc/systemd/system/docker.service.d
    systemctl daemon-reload
    systemctl restart docker
    log_msg "Docker installed successfully."
}

# Function to install Kubernetes
install_kubernetes() {
    log_msg "Installing Kubernetes..."
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
    apt update
    apt install -y kubeadm kubelet kubectl
    apt-mark hold kubelet kubeadm kubectl

    cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables=1
net.bridge.bridge-nf-call-iptables=1
EOF

    sysctl --system
    log_msg "Kubernetes installed successfully."
}

# Function to configure VM tools
configure_vmtools() {
    log_msg "Configuring VM tools..."
    cat >> /etc/vmware-tools/tools.conf <<EOF

[guestinfo]
primary-nics=eth0
exclude-nics=antrea-*,cali*,ovs-system,br*,flannel*,veth*,docker*,virbr*,vxlan_sys_*,genev_sys_*,gre_sys_*,stt_sys_*,????????-??????
EOF

    systemctl restart vmtoolsd
    log_msg "VM tools configured successfully."
}

# Main execution
log_msg "Starting the installation script."
disable_swap
install_docker
install_kubernetes
configure_vmtools
log_msg "Script execution completed."
