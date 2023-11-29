# Kubernetes Install
Ставим SCSI контроллер в VM на VMWARE-PARAvirtual (Для настройки vSphere Container Storage Plug-in)
Install Ubuntu Server Minimazed - Выбираем при инсталляции Ubuntu Server

## disk.EnableUUID=1 (For VMware)
Install govc 

For Windows:

```powershell
# Create credential store for vCenter authentication:

$vcenter = "172.18.7.151"
$cred = get-credential
New-VICredentialStoreItem -Host $vcenter -User $cred.username -Password $cred.GetNetworkCredential().password
$env:GOVC_URL="https://"+$vcenter
$env:GOVC_USERNAME=(Get-VICredentialStoreItem $vcenter).User
$env:GOVC_PASSWORD=(Get-VICredentialStoreItem $vcenter).Password
$env:GOVC_INSECURE="true"
# To print your session GOVC variables, you can run the following (note that the password will be in plaintext, no way around it as far as I know):
ls env:GOVC*
# Now you should be able to run govc to interface with vCenter API:
govc about
```

```powershell
govc ls
govc ls '/SZTU Datacenter/vm/SZTU/VM OSVTiO/Kubernetes'
```

```powershell
# Ставим disk.EnableUUID=TRUE на всех VM
govc vm.change -vm /"SZTU Datacenter"/vm/SZTU/"VM OSVTiO"/Kubernetes/sztu-kubms-vt01 -e="disk.enableUUID=TRUE"
# Проверяем что в Edit Settings - Advanced Parametrs Появилось disk.enableUUID TRUE
```

## Первоначальная настройка
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
Создаем каталоги kubespray-venv для виртуального окружения и kubespray для проекта
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

# Вроде бы чтобы это работало в arp режиме в vsphere нужно включить promiscous mode enable на vswitch? 
# Манифесты kube-vip находятся здесь /etc/kubernetes/manifests/
# Чтобы установить kube-vip вручную мы должны поместить туда манифесты и выполнить команду
# kubeadm init --control-plane 10.0.2.5
# Чтобы установить kube-vip на других нодах нужно используя вывод команды kubeadm init выполнить команду kubeadm join
# Kube VIP
kube_vip_enabled: true
kube_vip_arp_enabled: true
kube_vip_controlplane_enabled: true
kube_vip_address: 172.18.7.60
loadbalancer_apiserver:
  address: "{{ kube_vip_address }}"
  port: 6443
kube_vip_interface: ens224
kube_vip_services_enabled: true
```

https://kube-vip.io/docs/installation/static/

# Генерация манифеста и помещение его в каталог /etc/kubernetes/manifests/
export VIP=172.18.7.60
export INTERFACE=ens224
KVVERSION=$(curl -sL https://api.github.com/repos/kube-vip/kube-vip/releases | jq -r ".[0].name")
# Для containerd (не docker)
alias kube-vip="ctr image pull ghcr.io/kube-vip/kube-vip:$KVVERSION; ctr run --rm --net-host ghcr.io/kube-vip/kube-vip:$KVVERSION vip /kube-vip"

# Генерируем манифест:
kube-vip manifest pod \
    --interface $INTERFACE \
    --address $VIP \
    --controlplane \
    --services \
    --arp \
    --leaderElection | tee /etc/kubernetes/manifests/kube-vip.yaml


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


```bash
# Настраиваем подключение к кластеру
mkdir -p ~/.kube
cp /home/master/projects/kubernetes_install/ansible/kubespray/inventory/mycluster/artifacts/admin.conf ~/.kube/config
```

## Ошибка Error  
Проблема возникает при начальной установке или при перезагрузке kubelet  
Не критично
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

## Upgrade addons

```bash
ansible-playbook -b -i inventory/mycluster/inventory.ini -u master --become --become-user=root cluster.yml --tags=apps -K
```

## Kube-Vip cloud provider install
https://kube-vip.io/docs/usage/cloud-provider/

```bash
kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml
kubectl create configmap -n kube-system kubevip --from-literal range-global=172.18.7.70-172.18.7.72
```

## Install Ingress-nginx
https://kubernetes.github.io/ingress-nginx/deploy/
```bash
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.loadBalancerIP=172.18.7.70 --set controller.metrics.enabled=true
```

## Integration with VMWare
https://docs.vmware.com/en/VMware-vSphere-Container-Storage-Plug-in/3.0/vmware-vsphere-csp-getting-started/GUID-0AB6E692-AA47-4B6A-8CEA-38B754E16567.html


VMware vSphere Container Storage Plug-in

- `CSI-плагин`: CSI-плагин отвечает за предоставление, присоединение и отсоединение volume от виртуальных машин, монтирование, форматирование и отмонтирование volumes из пода внутри виртуальной машины узла и так далее. Он разрабатывается как CSI-плагин вне ядра для Kubernetes.

- `Syncer`: Syncer отвечает за передачу метаданных PV, PVC и пода в `CNS`. Он также предоставляет оператор CNS, который используется в vSphere с Tanzu. Дополнительную информацию можно найти в документации vSphere с Tanzu.

Components of the vSphere Container Storage Plug-in

1) vSphere Container Storage Plug-in Controller

  vSphere Container Storage Plug-in Controller предоставляет интерфейс, используемый kubernetes для управления жизненным циклом томов vSphere. Он также позволяет создавать, расширять и удалять тома, а также подключать и отключать тома от node VM.

2) vSphere Container Storage Plug-in Node

  vSphere Container Storage Plug-in Node позволяет форматировать и монтировать тома на nades, а также использовать привязки монтирования для томов внутри pods. Перед тем как том отсоединится, узел плагина хранилища контейнеров vSphere помогает отмонтировать том с узла. Узел плагина хранилища контейнеров vSphere работает как daemonset внутри кластера.

2) Syncer (Синхронизатор)

Syncer метаданных отвечает за передачу метаданных PV, PVC и пода в CNS. Данные отображаются в панели управления CNS в клиенте vSphere. Эти данные помогают администраторам vSphere определить, какие кластеры Kubernetes, приложения, поды, PVC и PV используют данный том.

Полная синхронизация отвечает за поддержание актуальности CNS с метаданными томов Kubernetes, такими как PV, PVC, поды и так далее. Полная синхронизация полезна в следующих случаях:

- CNS выходит из строя.
- Pod плагина хранилища контейнеров vSphere выходит из строя.
- Сервер API выходит из строя или ядро служб Kubernetes выходит из строя.
- Сервер vCenter восстанавливается до точки восстановления из резервной копии.
- etcd восстанавливается до точки восстановления из резервной копии.

## Устанавливаем taints на все ноды 

When the kubelet is started with an external cloud provider, this taint is set on a node to mark it as unusable. After a controller from the cloud-controller-manager initializes this node, the kubelet removes this taint.

```bash
kubectl get nodes
kubectl taint node <node-name> node.cloudprovider.kubernetes.io/uninitialized=true:NoSchedule
kubectl describe nodes | egrep "Taints:|Name:"
```

## Install vSphere Cloud Provider Interface
Download Change and Install vsphere-cloud-controller-manager.yaml

Если версия kubernetes 1.28.x то прописываем
```bash
VERSION=1.28
# Скачиваем
wget https://raw.githubusercontent.com/kubernetes/cloud-provider-vsphere/release-$VERSION/releases/v$VERSION/vsphere-cloud-controller-manager.yaml
```
Изменяем для нашего сервера

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cloud-controller-manager
  labels:
    vsphere-cpi-infra: service-account
    component: cloud-controller-manager
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: vsphere-cloud-secret
  labels:
    vsphere-cpi-infra: secret
    component: cloud-controller-manager
  namespace: kube-system
  # NOTE: this is just an example configuration, update with real values based on your environment
stringData:
  1.1.1.1.username: "Administrator@vsphere.local"
  1.1.1.1.password: "StrongPassword"
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vsphere-cloud-config
  labels:
    vsphere-cpi-infra: config
    component: cloud-controller-manager
  namespace: kube-system
data:
  # NOTE: this is just an example configuration, update with real values based on your environment
  vsphere.conf: |
    # Global properties in this section will be used for all specified vCenters unless overriden in VirtualCenter section.
    global:
      port: 443
      # set insecureFlag to true if the vCenter uses a self-signed cert
      insecureFlag: true
      # settings for using k8s secret
      secretName: vsphere-cloud-secret
      secretNamespace: kube-system

    # vcenter section
    vcenter:
      1.1.1.1:
        server: 1.1.1.1
        datacenters:
          - "Datacenter"
---

....
```

Применяем
```bash
kubectl apply -f vsphere-cloud-controller-manager.yaml
# Если надо удалить
rm vsphere-cloud-controller-manager.yaml
```

## Deploying the vSphere Container Storage Plug-in on a Native Kubernetes Cluster


### Create namespace

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/vsphere-csi-driver/v3.0.0/manifests/vanilla/namespace.yaml
```
Ставим taints на control plane
```bash
# Проверяем что не стоит
kubectl describe nodes | egrep "Taints:|Name:"
# ставим если не стоит
kubectl taint nodes <k8s-primary-name> node-role.kubernetes.io/control-plane=:NoSchedule
```