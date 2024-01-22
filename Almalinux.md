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

# Prerequisites

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

# Этот файл config.toml взят из kubespray
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
- docker запускает контейнеров в namespace mobi. 
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

`overlay` it’s needed for overlayfs, checkout more info here https://www.kernel.org/doc/html/latest/filesystems/overlayfs.html.  
`br_netfilter` for iptables to correctly see bridged traffic, checkout more info here https://ebtables.netfilter.org/documentation/bridge-nf.html

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

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: v1.28.0
# Адрес Ha-Proxy сервера
controlPlaneEndpoint: 192.168.0.149:6443
# Сеть для подов (calico по default использует эту сеть)
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

```bash
# Disable
systemctl stop firewalld
systemctl disable firewalld
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
# or
mkdir -p ~/.kube
cp /etc/kubernetes/admin.conf ~/.kube/config
```

# Ставим сетевой плагин

```bash
kubectl apply -f calico.yaml
```
Изменения внесенные в calico:
```yaml
            # Auto-detect the BGP IP address.
            - name: NODEIP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.hostIP
            # can-reach метод который указывает на адрес узла 
            # также есть метод kubernetes internal ip который тоже можно использовать (подставляет интерфейс на котором находится внутренний адрес узла)
            - name: IP_AUTODETECTION_METHOD
              value: can-reach=$(NODEIP)
            # Ip интерфейса через который работает calico берется из IP_AUTODETECTION_METHOD
            - name: IP
              value: "autodetect"
            # Enable IPIP
            - name: CALICO_IPV4POOL_IPIP
              value: "CrossSubnet"
            # Enable or Disable VXLAN on the default IP pool.
            - name: CALICO_IPV4POOL_VXLAN
              value: "Never"
```

По default calico берет первый ip адрес с первого интерфейса который она нашла.  
Дополнительно мы можем указать адрес узла из статуса kubectl get node -o wide (Раздел INTERNAL-IP)  
Можем использовать функцию can reach: google.com тот интерфейс через который будет доступен google и будет работать calico  
Можем указать REGEXP  
Или Skip REGEXP  
Или CIDR (Указываем подсеть)  
У calico есть база данных которая хранит свои ресурсы либо etcd отдельно от ресурсов kube либо кастомные ресурсы kube crd создаются (Это default вариант)  
У calico есть своя утилита calicoctl

```bash
cd /usr/bin
curl -L https://github.com/projectcalico/calico/releases/download/v3.26.4/calicoctl-linux-amd64 -o calicoctl
calicoctl get nodes
```

# Проверяем, что всё заработало

```bash
kubectl get node
kubectl get po -A
```

# Worker Install

## Установить hostname

```bash
hostnamectl set-hostname kub-worker-01
reboot
nano /etc/hosts
```

## Generate new uuid for hyper-v clone

C:\Projects\kubernetes_install\New-BIOSGUIDgenerator.ps

## Change Machine ID

```bash
cat /etc/machine-id
rm /etc/machine-id
# Initializing machine ID from random generator.
systemd-machine-id-setup
cat /etc/machine-id
```

## Change mac address
В дополнительных параметрах сетевой карты Hyper-v

## Change Ip
```bash
# IPv4
nmcli connection modify eth0 ipv4.addresses 192.168.0.151/24
# restart the interface to reload settings
nmcli connection down eth0; nmcli connection up eth0
```

## Change Sandbox Image
```bash
nano /etc/containerd/config.toml

sandbox_image = "registry.k8s.io/pause:3.9"
systemctl restart containerd
```

## Генерируем новый токен
```bash
kubeadm token generate
5zme0q.jlumz8renz5g1pbx
kubeadm token create 5zme0q.jlumz8renz5g1pbx --print-join-command
```

## Присоединяем Worker Node

```bash
kubeadm join 192.168.0.149:6443 --token 5zme0q.jlumz8renz5g1pbx --discovery-token-ca-cert-hash sha256:0ae08a253dd14bc3df18b263e4a1650f14afab24ea77ef60d6d7228068aea26d
```

## Ставим Label для Worker Node

```bash
kubectl label node kub-worker-01 node-role.kubernetes.io/node=""
```

# Ставим helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
mv /usr/local/bin/helm /usr/bin
```

# Ставим ingress-controller

```bash
helm show values ingress-nginx --repo https://kubernetes.github.io/ingress-nginx > nginx-ingress-original.yaml
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

Изменения сделанные в yaml
```yaml
controller:
  # Файл конфигурации, записывает в configmap
  config:
    # Не нужно в access-log писать запросы к health check-ам (kubelet раз в 15 секунд делает эти запросы)
    skip-access-log-urls: /health,/healthz,/ping
    # Когда меняется конфигурация ingress controller то reload-ся nginx
    # а старая версия обрабатывает запросы и может висеть часами, эта настройка убивает старую версию nginx через 30 сек
    worker-shutdown-timeout: "30"
  

  # -- Optionally change this to ClusterFirstWithHostNet in case you have 'hostNetwork: true'.
  # By default, while using host network, name resolution uses the host's DNS. If you wish nginx-controller
  # to keep resolving names inside the k8s network, use ClusterFirstWithHostNet.
  dnsPolicy: ClusterFirstWithHostNet

  # -- This configuration defines if Ingress Controller should allow users to set
  # their own *-snippet annotations, otherwise this is forbidden / dropped
  # when users add those annotations.
  # Global snippets in ConfigMap are still respected
  allowSnippetAnnotations: true

  # -- Required for use with CNI based kubernetes installations (such as ones set up by kubeadm),
  # since CNI and hostport don't mix yet. Can be deprecated once https://github.com/kubernetes/kubernetes/issues/23920
  # is merged
  # Внутри подов прописан сетевой namespace узла, (Более простой и быстрый вариант если не настроен Load Balancer)
  hostNetwork: true

  # -- Election ID to use for status update
  electionID: ingress-controller-leader

  replicaCount: 2
  priorityClassName: "system-cluster-critical"
## If true, create & use Pod Security Policy resources
## https://kubernetes.io/docs/concepts/policy/pod-security-policy/
podSecurityPolicy:
  enabled: true
```

```bash
helm upgrade --install ingress-nginx ingress-nginx -f nginx-ingress-changed.yaml --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.metrics.enabled=true
```

# Coredns
Dns сервер который работает в кластере, он ходит в api kubernetes и берет от туда информацию о запущенных сервисах и какие адреса у этих сервисов.

Исправляем проблему с восемью запросами

В каждом поде появляется файл `etc/resolv.conf` (В нем содержится информация о `dns сервере` (`ip CoreDNS`) и `search` домен)  
Сначала будут разрешаться внутренние `search` домены (`.default.svc.cluster.local.` `.svc.cluster.local.` `.cluster.local.` `.local.`) для кластера и поэтому когда мы будем делать запрос в интернет (например `ya.ru`) у нас будет очень много лишних запросов к внутренним dns.  

Запускаем тестовый под, заходим в него с двух консолей и смотрим на вывод `tcpdump`

```bash
kubectl run -t -i --rm --image centosadmin/utils test bash
# Команда для просмотра dns запросов
tcpdump -neli eth0 port 53
```

Идем во вторую консоль
```bash
# из второй консоли:
kubectl exec -it test -- bash
curl ya.ru
```

Видим в первой консоли количество запросов

Решение:
1. Вариант Создавать node local dns (kubespray его ставит) на всех нодах которые будут кешировать запросы и послать или локально внутри узла или на coreDNS по TCP (Это лучше для приложений работающих на udp чтобы не пропадали пакеты)
2. Вариант Включить autopath в CoreDNS (На запрос ya.ru.default.svc.cluster.local нам сразу придет ответ что это cname для ya.ru) CoreDNS становиться более интеллектуальным

    ```bash
    kubectl edit configmap -n kube-system coredns
    # В открывшемся файле меняем
    pods insecure
    # на
    pods verified
    # и дописываем под словом ready
    autopath @kubernetes
    ```
Файл конфигурации перечитывается время от времени  
Проверяем `curl ya.ru`

# kubelet

Опции которые указываются у kubelet на узле

Эти параметры важны в production (отвечают за резервирование ресурсов под систему (под kubelet))
```bash
# Когда запускается pod на каком то узле то у этого pod есть request и limit
# Если в request и limit указать целое количество ядер (и они должны быть равны) для приложения то kubelet будет выделять этому приложению эксклюзивно эти два cpu и приложение никуда не будет переезжать на другие ядра и другим приложениям эти ядра выделяться не будут. Есть проблема с виртуальными машинами, если у нас были машины с двумя ядрами а потом мы увеличим их до 8 то kubelet не запуститься будет ошибка. В каталоге /var/lib/kubelet есть файл в котором прописана эта настройка, его нужно удалить и сделать restart kubelet тогда kubelet его создаст заново с новыми параметрами.
--cpu-manager-policy=static
# Параметры при наступлении которых kubelet начинает выселять pod со своего узла 
# Размещение pod на узлах идет по request, scheduler не проверяет сколько свободных limit есть на узле. И если количество limit будет больше чем количество свободных ресурсов на узле (т.е limit не исчерпаны а ресурсов уже нет) kubelet начнет убивать поды на узле сначала поды самого низкого класса обслуживания.
# Сколько памяти должно оставаться на узле не занятым нашими приложениями:
--eviction-hard=memory.available<1Gi
# Начинаем процедуру эвакуации если меньше 1Gi до тех пор пока не освободиться 2Gi:
--eviction-minimum-reclaim=memory.available=2Gi
# Сколько ждать удаления pod которые завершаются по процедуре эвакуации. после 30 сек будет kill -9 
--eviction-max-pod-grace-period=30
# Ресурсы которые выделяются под систему
--system-reserved=memory=1.5Gi,cpu=1
# Ресурсы которые выделяются под kubelet
--kube-reserved=memory=512Mi,cpu=500m
# Эти ресурсы нельзя будет распределять под приложения
```

# Утилита crictl

```bash
# Посмотреть запущенные контейнеры
crictl ps
# Посмотреть скачанные образы
crictl images ls
# Посмотреть логи контейнера kube-apiserver
crictl logs ef26623bd919a
```
Эта утилита больше для просмотра, посмотреть контейнеры и логи контейнера

# Утилита nerdctl

Умеет запускать контейнеры. Есть команда run
```bash
# Нужно указывать namespace
nerdctl -n k8s.io ps
```

# Добавление kubectl bash completion (автозаполнение по tab)
https://kubernetes.io/ru/docs/tasks/tools/install-kubectl/

```bash
yum install bash-completion
# Проверка
exit
# заходим обратно если команда отработало то все успешно
type _init_completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
# Выходим заходим проверяем
```

Выходим из sudo-сессии root, заходим назад, чтобы профиль перечитался.

Создаем StorageClass для Local Storage

```yaml
# https://kubernetes.io/docs/concepts/storage/storage-classes/#local
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage-rabbitmq
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

Создаем PersistentVolume для StorageClass
```yaml
# https://kubernetes.io/docs/concepts/storage/volumes/#local
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-manual-rabbitmq
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage-rabbitmq
  local:
    path: /mnt/data/rabbitmq ## this folder need exist on your node. Keep in minds also who have permissions to folder. Used tmp as it have 3x rwx
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - kub-worker-01
```
