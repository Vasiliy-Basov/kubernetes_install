# HaProxy Install
```bash
sudo dnf update -y
hostnamectl set-hostname ha-proxy
# Меняем /etc/hosts
sudo dnf install nano
nano /etc/hosts
sudo dnf info haproxy -y
sudo dnf install haproxy
# Проверка
rpm -qi haproxy
# Backup config
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.bak
# Disable SELinux
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
sudo setenforce 0
# Change config
# ./haproxy.cfg
nano /etc/haproxy/haproxy.cfg
# Проверка
haproxy -f /etc/haproxy/haproxy.cfg -c
# В firewalld исходящий трафик обычно разрешен по умолчанию
# Открываем входящий
sudo firewall-cmd --add-port=8399/tcp --permanent
sudo firewall-cmd --add-port=2379/tcp --permanent
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo firewall-cmd --reload
```

# Prerequisutes
- 2 GB or more of RAM per machine
- 2 CPUs or more.
- Unique hostname, MAC address, and product_uuid for every node.
sudo cat /sys/class/dmi/id/product_uuid
- Swap disabled. You MUST disable swap in order for the kubelet to work properly.

# Посмотреть текущий конфиг сети
```bash
nmcli device
nmcli device show eth0
# и
cd /etc/NetworkManager/system-connections/
sudo cat /etc/NetworkManager/system-connections/eth0.nmconnection
```

# Установить hostname

```bash
hostnamectl set-hostname kub-master-01
reboot
```

# Установить необходимые пакеты
```bash
sudo dnf install -y git curl vim iproute-tc
```

# Установить сетевые настройки

```bash
# IPv4
nmcli connection modify eth0 ipv4.addresses 172.18.201.205/20
# Gateway
nmcli connection modify eth0 ipv4.gateway 172.18.192.1
# DNS
nmcli connection modify eth0 ipv4.dns 172.18.192.1
# set DNS search base (your domain name -for multiple one, specify with space separated)
nmcli connection modify eth0 ipv4.dns-search mshome.net
# no dhcp
nmcli connection modify eth0 ipv4.method manual
# restart the interface to reload settings
nmcli connection down eth0; nmcli connection up eth0
# Просмотр
nmcli device show eth0
ip a
```

# Установка containerd

```bash
# add repo
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
# Check version 
dnf info containerd.io
# Install 
dnf install -y containerd.io-1.6.24-3.1.el9
# Можем создать default config
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Проверяем какой sandbox image использовать в config.toml: sandbox_image = "registry.k8s.io/pause:3.9" 
kubeadm config images list

cat > /etc/containerd/config.toml <<EOF
#   Copyright 2018-2022 Docker Inc.
version = 2
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# disabled_plugins = ["cri"]
#root = "/var/lib/containerd"
#state = "/run/containerd"
#subreaper = true
#oom_score = 0

[grpc]
#  address = "/run/containerd/containerd.sock"
#  uid = 0
#  gid = 0
  max_recv_message_size = 16777216
  max_send_message_size = 16777216

[debug]
#  address = "/run/containerd/debug.sock"
#  uid = 0
#  gid = 0
  level = "info"

[metrics]
  address = ""
  grpc_histogram = false

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    sandbox_image = "registry.k8s.io/pause:3.9"
    max_container_log_line_size = -1
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      snapshotter = "overlayfs"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          runtime_engine = ""
          runtime_root = ""
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            systemdCgroup = true
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://mirror.gcr.io","https://registry-1.docker.io"]
EOF

systemctl enable --now containerd
systemctl restart containerd
systemctl status containerd
```

# Скачиваем и распаковываем утилиты crictl и nerdctl

```bash
dnf install -y tar
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.28.0/crictl-v1.28.0-linux-amd64.tar.gz | tar -zxf - -C /usr/bin

cat > /etc/crictl.yaml <<EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 30
debug: false
EOF
crictl ps

# Аналог docker для containerd
curl -L https://github.com/containerd/nerdctl/releases/download/v1.7.0/nerdctl-1.7.0-linux-amd64.tar.gz | tar -zxf - -C /usr/bin
nerdctl ps
```

В containerd есть namespace, это не kubernetes namespace. Они позволяют разделить контейнеры запущенные различными утилитами. Например 
- docker запускает контейнерв в namespace mobi. 
- kubelet запускает контейнеры в namespace k8s.io. 
- nerdctl запускает в собственном namespace.

Посмотреть контейнеры kubelet
```bash
nerdctl ps -n k8s.io ps
```

# Disable SELinux

```bash
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo setenforce 0
```

# Disable Swap

```bash
# Удаляем строки содержащие swap
sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a
```

# Letting iptables see bridged traffic

```bash
# Make sure that the br_netfilter module is loaded. This can be done by running 
lsmod | grep br_netfilter
# To load it explicitly call 
sudo modprobe br_netfilter
```

`overlay` it’s needed for overlayfs, checkout more info here https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html. `br_netfilter` for iptables to correctly see bridged traffic, checkout more info here https://ebtables.netfilter.org/documentation/bridge-nf.html


каталог /etc/modules-load.d/ это каталог для загрузки модулей в ядро (файлы с расширением conf)

```bash
sudo cat << EOF | sudo tee /etc/modules-load.d/br_netfilter.conf
overlay
br_netfilter
EOF
```

As a requirement for your Linux Node’s iptables to correctly see bridged traffic, you should ensure net.bridge.bridge-nf-call-iptables is set to 1 in your sysctl config, e.g.

```bash
sudo cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
```

Apply settings
```bash
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl --system
```

# Проверяем chrony
```bash
systemctl status chronyd
chronyc sources
timedatectl
cat /etc/chrony.conf
# To Install NTPStat, it's possible to display time synchronization status
dnf -y install ntpstat
ntpstat
```

# Install kubelet, kubeadm and kubectl

```bash
# Add repo
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
```

```bash
# install kubeadm and the required packages:
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
```

```bash
# Lock versions in order to avoid unwanted updated via yum or dnf update
sudo dnf install yum-plugin-versionlock -y
sudo dnf versionlock kubelet kubeadm kubectl
```

```bash
# Enable and start kubelet
systemctl enable --now kubelet
systemctl status kubelet
# Это нормально: (code=exited, status=1/FAILURE), err="failed to load kubelet config file, path: /var/lib/kubelet/config.yaml
```

# Правим файл с конфигурацией для kubeadm `cluster.yaml`

```
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
controlPlaneEndpoint: 192.168.0.149:6443
networking:
  podSubnet: 10.244.0.0/16
```

# Firewall
```bash
# master
firewall-cmd --add-port={6443,2379-2380,10250,10251,10252,5473,179,5473}/tcp --permanent
firewall-cmd --add-port={4789,8285,8472}/udp --permanent
firewall-cmd --reload

#worker
firewall-cmd --add-port={10250,30000-32767,5473,179,5473}/tcp --permanent
firewall-cmd --add-port={4789,8285,8472}/udp --permanent
firewall-cmd --reload
```


# Создаем кластер

```bash
kubeadm init --config cluster.yaml --upload-certs --ignore-preflight-errors NumCPU | tee -a kubeadm_init.log
```

```bash
# To start using your cluster, you need to run the following as a regular user:

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


# Alternatively, if you are the root user, you can run:

export KUBECONFIG=/etc/kubernetes/admin.conf
```

# Ставим сетевой плагин

```bash
kubectl apply -f calico.yaml
```

# Проверяем, что всё заработало

```bash
kubectl get node
kubectl get po -A
```

