#!/bin/bash

## Set variables values
MASTER_IP=192.168.56.2

lsmod | grep br_netfilter
sudo modprobe br_netfilter
lsmod | grep br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

## INSTALLING DOCKER ENGINE BASED ON OS

yum --help &>> /dev/null
if [ $? -eq 0 ]
then
  # (Install Docker CE)
  ## Set up the repository
  ### Install required packages
  yum install -y yum-utils device-mapper-persistent-data lvm2
  ## Add the Docker repository
  yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  # Install Docker CE
  yum update -y && yum install -y \
    containerd.io-1.2.13 \
    docker-ce-19.03.11 \
    docker-ce-cli-19.03.11
  ## Create /etc/docker
  mkdir /etc/docker
  # Set up the Docker daemon
  cat > /etc/docker/daemon.json <<EOF
  {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "100m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ]
  }
EOF
  mkdir -p /etc/systemd/system/docker.service.d
  # Restart Docker
  systemctl daemon-reload
  systemctl restart docker
  sudo systemctl enable docker

else
  # (Install Docker CE)
  ## Set up the repository:
  ### Install packages to allow apt to use a repository over HTTPS
  apt-get update && apt-get install -y \
    apt-transport-https ca-certificates curl software-properties-common gnupg2
  # Add Docker's official GPG key:
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  # Add the Docker apt repository:
  add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  # Install Docker CE
  apt-get update && apt-get install -y \
    containerd.io=1.2.13-2 \
    docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
    docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)
  # Set up the Docker daemon
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
  # Restart Docker
  systemctl daemon-reload
  systemctl restart docker
  sudo systemctl enable docker

  ##### ADDED: cri-dockerd
  cd /tmp
  wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.12/cri-dockerd-0.3.12.amd64.tgz
  tar xvf cri-dockerd-0.3.12.amd64.tgz
  sudo mv cri-dockerd /usr/local/bin
  #cri-dockerd --version
  #cri-dockerd 0.2.0 (HEAD)
  wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
  wget https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket
  sudo mv cri-docker.socket cri-docker.service /etc/systemd/system/
  sudo sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
  
  sudo chmod +x /etc/systemd/system/cri-docker.socket
  sudo chmod +x /etc/systemd/system/cri-docker.service

  
  sudo systemctl daemon-reload
  sudo systemctl enable cri-docker.service
  sudo systemctl enable --now cri-docker.socket

  cd /usr/local/bin/cri-dockerd
  sudo ./cri-dockerd&


  ######



########

fi

sleep 30

## Installing kubeadm, kubelet and kubectl
yum --help &>> /dev/null
if [ $? -eq 0 ]
then
   cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
   [kubernetes]
   name=Kubernetes
   baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
   enabled=1
   gpgcheck=1
   repo_gpgcheck=1
   gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
   exclude=kubelet kubeadm kubectl
EOF

   # Set SELinux in permissive mode (effectively disabling it)
   sudo setenforce 0
   sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

   sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

   sudo systemctl enable --now kubelet
   systemctl stop firewalld
   systemctl disable firewalld

else

   #sudo apt-get update && sudo apt-get install -y apt-transport-https curl
   #curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   #cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
   #deb https://apt.kubernetes.io/ kubernetes-xenial main

   ######## ADDED:
   sudo apt-get update
   # apt-transport-https may be a dummy package; if so, you can skip that package
   sudo apt-get install -y apt-transport-https ca-certificates curl gpg

   # If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
   sudo mkdir -p -m 755 /etc/apt/keyrings
   curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

   # This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
   #######




EOF
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   sudo apt-mark hold kubelet kubeadm kubectl
   systemctl stop ufw
   systemctl disable ufw
fi

#sleep 30



###### ADDED
#sudo kubeadm config images pull --cri-socket /run/cri-dockerd.sock
#nano /etc/sysconfig/kubelet
# add the following flags to KUBELET_KUBEADM_ARGS variable
#KUBELET_KUBEADM_ARGS="... --container-runtime=remote --container-runtime-endpoint=/run/cri-dockerd.sock"
#sudo kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock
#########





#sudo kubeadm init --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=192.168.56.2 > /tmp/kubeadm_out.log
## ADDED
sudo kubeadm init --cri-socket unix:///var/run/cri-dockerd.sock --pod-network-cidr 10.244.0.0/16 --apiserver-advertise-address=192.168.56.2 > /tmp/kubeadm_out.log
##

sleep 360
#/vagrant/set-kubeconfig.sh
## ADDED
sudo chmod +x /vagrant/set-kubeconfig.sh
/vagrant/set-kubeconfig.sh



sudo kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
sleep 60
sudo cat /tmp/kubeadm_out.log | grep -A1 'kubeadm join' > /vagrant/cltjoincommand.sh
sudo chmod +x /vagrant/cltjoincommand.sh
