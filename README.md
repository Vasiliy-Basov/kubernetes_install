# Kubernetes Install

Install Ubuntu Server Minimazed - Выбираем при инсталляции Ubuntu Server

```bash
# Generate ssh key pair to connect
ssh-keygen -t ed25519 -C "your_email@example.com"
# Impliment ssh.pub to authorized_keys
cat id_ed25519.pub >> ~/.ssh/authorized_keys
# Меняем имя
sudo nano /etc/hostname
sudo nano /etc/hosts
```

## Install ansible in venv  
Содаем каталоги kubespray-venv для виртуального окружения и kubespray для проекта
```bash
sudo apt update
sudo apt install python3.10-venv
# Это будет именем для виртуального окружения Python
VENVDIR=kubespray-venv
# Это указывает на каталог проекта Kubespray
KUBESPRAYDIR=kubespray
# Эта команда создает виртуальное окружение Python с именем, указанным в переменной VENVDIR
python3 -m venv $VENVDIR
#  Эта строка активирует только что созданное виртуальное окружение. После выполнения этой команды ваш командный интерпретатор будет использовать Python и установленные пакеты из виртуального окружения.
source $VENVDIR/bin/activate
# Эта команда переключает текущий рабочий каталог на каталог проекта Kubespray, указанный в переменной KUBESPRAYDIR
cd $KUBESPRAYDIR
# Наконец, эта команда использует инструмент управления пакетами Python pip для установки или обновления пакетов, перечисленных в файле requirements.txt. Эти пакеты представляют собой зависимости проекта Kubespray
pip install -U -r requirements.txt
# Выйти из виртуального окружения
deactivate
# Заново активировать
source /home/master/projects/kubernetes_install/ansible/kubespray-venv/bin/activate
```

```bash
# Смена hostname
sudo nano /etc/hostname

# Очистка
sudo nano /etc/machine-id
# Удалите старый machine-id
sudo rm /etc/machine-id
# Сгенерируйте новый machine-id
sudo systemd-machine-id-setup

# Смена ip
sudo nano /etc/netplan/00-installer-config.yaml
sudo chmod 600 /etc/netplan/00-installer-config.yaml

```yaml
# This is the network config written by 'subiquity'
network:
  version: 2
  ethernets:
    ens160:
      dhcp4: false
      addresses:
      - 10.100.3.14/24
      nameservers:
        addresses: [8.8.8.8]
        search: []
      routes:
      - to: default
        via: 10.100.3.1
    ens192:
      dhcp4: false
      addresses:
      - 172.18.7.51/23
      nameservers:
        addresses: [172.18.5.207]
        search: [regions.eais.customs.ru]
    # For kube-vip этот ip должен быть на всех control plane (на каждом свой) но должен отличаться от виртуального ip который мы прописываем в kube_vip_address или можно вообще не использовать этот интерфейс а использовать ens192.
    ens224:
      dhcp4: false
      addresses:
      - 172.18.7.60/23
```

## Настройка /etc/hosts

/home/master/projects/kubernetes_install/ansible/roles/hosts/templates/hosts.j2

```text
127.0.0.1 localhost
172.18.7.52 sztu-kubms-vt01
172.18.7.60 sztu-kubms-vt01
172.18.7.53 sztu-kubms-vt02
172.18.7.55 sztu-kubws-vt01

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```
```bash
# Распространяем на все наши хосты
ansible-playbook --limit all ./playbooks/ubuntuhosts.yaml --private-key /home/master/.ssh/id_ed25519 -K
```

# настройки сети (dns)
```bash
sudo cat /etc/resolv.conf
# Меняем настройки чтобы /etc/resolv.conf управлялся из файла /etc/netplan/00-installer-config.yaml
sudo unlink /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo systemctl restart systemd-resolved.service
```

# Установка с помощью kubspray
```bash
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
cp -r inventory/sample inventory/mycluster
```

Меняем файл /home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/inventory.ini  
Можем создать host.yaml из python скрипта или вручную  
```ini
# ## Configure 'ip' variable to bind kubernetes services on a
# ## different ip than the default iface
# ## We should set etcd_member_name for etcd cluster. The node that is not a etcd member do not need to set the value, or can set the empty string value.
[all]
sztu-kubms-vt01 ansible_host=172.18.7.52 ip=172.18.7.52 etcd_member_name=etcd1
sztu-kubms-vt02 ansible_host=172.18.7.53 ip=172.18.7.53 etcd_member_name=etcd2
sztu-kubws-vt01 ansible_host=172.18.7.55 ip=172.18.7.55 etcd_member_name=etcd3
# node1 ansible_host=95.54.0.12  # ip=10.3.0.1 etcd_member_name=etcd1

# ## configure a bastion host if your nodes are not directly reachable
# [bastion]
# bastion ansible_host=x.x.x.x ansible_user=some_user

[kube_control_plane]
sztu-kubms-vt01
sztu-kubms-vt02

[etcd]
sztu-kubms-vt01
sztu-kubms-vt02
sztu-kubws-vt01

[kube_node]
sztu-kubms-vt02
sztu-kubws-vt01

[calico_rr]

[k8s_cluster:children]
kube_control_plane
kube_node
calico_rr
```

## Настройка group_vars
/home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/group_vars  

Изменения которые сделаны

/home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
```yaml
# This is the user that owns tha cluster installation.
kube_owner: master
# Kube-proxy proxyMode configuration.
# Can be ipvs, iptables
# kube_proxy_mode: iptables

# Make a copy of kubeconfig on the host that runs Ansible in {{ inventory_dir }}/artifacts
kubeconfig_localhost: true
# Use ansible_host as external api ip when copying over kubeconfig.
# kubeconfig_localhost_ansible_host: false
# Download kubectl onto the host that runs Ansible in {{ bin_dir }}
kubectl_localhost: true

# Для kube-vip не до конца понял нужно ли включать в случае kube_proxy_mode: iptables
# https://github.com/kubernetes-sigs/kubespray/blob/master/docs/kube-vip.md
# configure arp_ignore and arp_announce to avoid answering ARP queries from kube-ipvs0 interface
# must be set to true for MetalLB, kube-vip(ARP enabled) to work
kube_proxy_strict_arp: true
```

/home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml
```yaml
# Helm deployment
helm_enabled: true

# Развертывание внутреннего приватного docker registry registry.default.svc.cluster.local порт 5000
# Registry deployment
registry_enabled: true
registry_namespace: kube-system
registry_storage_class: ""
registry_disk_size: "10Gi"

# Metrics Server deployment
metrics_server_enabled: true
metrics_server_container_port: 10250
metrics_server_kubelet_insecure_tls: true
metrics_server_metric_resolution: 15s
metrics_server_kubelet_preferred_address_types: "InternalIP,ExternalIP,Hostname"
metrics_server_host_network: false
metrics_server_replicas: 1

# Local volume provisioner deployment
local_volume_provisioner_enabled: true
local_volume_provisioner_namespace: kube-system
# local_volume_provisioner_nodelabels:
#   - kubernetes.io/hostname
#   - topology.kubernetes.io/region
#   - topology.kubernetes.io/zone
local_volume_provisioner_storage_classes:
  local-storage:
    host_dir: /mnt/disks
    mount_dir: /mnt/disks
    volume_mode: Filesystem
    fs_type: ext4
#   fast-disks:
#     host_dir: /mnt/fast-disks
#     mount_dir: /mnt/fast-disks
#     block_cleaner_command:
#       - "/scripts/shred.sh"
#       - "2"
#     volume_mode: Filesystem
#     fs_type: ext4
# local_volume_provisioner_tolerations:
#   - effect: NoSchedule
#     operator: Exists

# Kube VIP
kube_vip_enabled: true
kube_vip_arp_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: 172.18.7.60
loadbalancer_apiserver:
  address: "{{ kube_vip_address }}"
  port: 6443
kube_vip_interface: ens224
# kube_vip_services_enabled: false
```

# Install
```bash
source /home/master/projects/kubernetes_install/ansible/kubespray-venv/bin/activate
# Обновляем все пакеты
ansible -i inventory/mycluster/inventory.ini -u master --become --become-user=root -m apt -a "update_cache=yes upgrade=dist" all -K
# Restart all nodes
ansible -i inventory/mycluster/inventory.ini -u master --become --become-user=root -m shell -o -a "nohup bash -c 'sleep 5s && reboot'" all -K

eval `ssh-agent`
ssh-add /home/master/.ssh/id_ed25519

ansible-playbook -i inventory/mycluster/inventory.ini -u master --become --become-user=root cluster.yml -K
```

Проверяем:

```bash
KUBECONFIG=/home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/artifacts/admin.conf kubectl get nodes -o wide
# Ставим label на worker node
export KUBECONFIG=/home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/artifacts/admin.conf 
kubectl label nodes sztu-kubws-vt01 kubernetes.io/role=worker
```

## Ошибка Err  
"invalid capacity 0 on image filesystem"
```bash
# Посмотреть логи kubelet
# -x - 
journalctl -xeu kubelet
journalctl -xeu kubelet | grep cri_stats_provider
journalctl -u kubelet | grep "invalid capacity"
# Просмотр информации по containerd
sudo nerdctl info
sudo containerd --version
# Просмотр информации по ОС и ядру
cat /etc/os-release
uname -a
```
Возможное решение
```bash
systemctl restart containerd
systemctl restart kubelet
```