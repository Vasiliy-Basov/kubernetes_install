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
    sandbox_image = "k8s.gcr.io/pause:3.3"
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
