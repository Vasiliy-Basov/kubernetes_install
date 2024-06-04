# Gitlab Install

## Change Ingress Options
Посмотреть как называется service gitlab

add --set tcp.22="gitlab/gitlab-gitlab-shell:22"  

https://kubernetes.github.io/ingress-nginx/deploy/

```bash
# Скачать чарт локально
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo ingress-nginx
helm pull ingress-nginx/ingress-nginx --untar
```
```bash
helm upgrade --install ingress-nginx /home/appuser/projects/kubernetes_install/ingress-nginx/ingress-nginx/ --namespace ingress-nginx --create-namespace -f /home/appuser/projects/kubernetes_install/ingress-nginx/nginx-ingress-changed.yaml
```

## Set reclaim Policy to Storage Class
Set reclaimPolicy to Retain on Storage Class

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ssd-local
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.vsphere.vmware.com
allowVolumeExpansion: true # Optional: only applicable to vSphere 7.0U1 and above
# При использовании Retain, ресурсы хранилища, связанные с PVC, не удаляются при удалении PVC
# В этом случае, если PVC удаляется, PV остается неизменным, и администратор кластера должен вручную принимать решение о том, что делать с PV.
reclaimPolicy: Retain
parameters:
  datastoreurl: "ds:///vmfs/volumes/12312avsihgbliou3ub2i3r9238hbr/"
  storagepolicyname: "Kuber-VMFS"
  csi.storage.k8s.io/fstype: ext4
```

```bash
# Download Chart Localy
helm pull gitlab/gitlab --untar
# Create values_changed.yaml
```
```yaml
# Need to set certmanager-issuer.email before templating
certmanager-issuer:
  email: a@google.com

global:
  kubectl:
    image:
      repository: registry.local/gitlab-org/build/cng/kubectl
      tag: v16.6.1
  certificates:
    image:
      repository: registry.local/gitlab-org/build/cng/certificates
      tag: v16.6.1
  gitlabBase:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-base
      tag: v16.6.1
  edition: ce
  hosts:
    domain: gitlab.local
    externalIP: 1.1.1.1
  kas:
    enabled: true
  ingress:
    configureCertmanager: false
    class: nginx
gitlab-runner:
  runners:
    privileged: true
  image:
    registry: registry.local
    image: gitlab-org/gitlab-runner
nginx-ingress:
  enabled: false
#  controller: *custom
certmanager:
  install: false
#  <<: *custom
#  cainjector: *custom

shared-secrets:
  selfsign:
    image: 
      repository: registry.local/gitlab-org/build/cng/cfssl-self-sign

# global:
#   certificates:
#     image:
#       repository: registry.local/gitlab-org/build/cngcertificates
#   kubectl:
#     image:
#       repository: registry.local/gitlab-org/build/cngkubectl
#   gitlabBase:
#     image:
#       repository: registry.local/gitlab-org/build/cnggitlab-base

gitlab:
  geo-logcursor:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-geo-logcursor
      tag: v16.6.1
  gitaly:
    image:
      repository: registry.local/gitlab-org/build/cng/gitaly
      tag: v16.6.1
  gitlab-exporter:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-exporter
      tag: v16.6.1
  gitlab-pages:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-pages
      tag: v16.6.1
  gitlab-shell:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-shell
      tag: v16.6.1
  mailroom:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-mailroom
      tag: v16.6.1
  migrations:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-toolbox-ce
      tag: v16.6.1
  praefect:
    image:
      repository: registry.local/gitlab-org/build/cng/gitaly
      tag: v16.6.1
  sidekiq:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-sidekiq-ce
      tag: v16.6.1
  toolbox:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-toolbox-ce
      tag: v16.6.1
  webservice:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-webservice-ce
      tag: v16.6.1
    workhorse:
      image: registry.local/gitlab-org/build/cng/gitlab-workhorse-ce
      tag: v16.6.1
  gitlab-kas:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-kas
      tag: v16.6.0
  kas:
    image:
      repository: registry.local/gitlab-org/build/cng/gitlab-kas
      tag: v16.6.0
# --- Charts from requirements.yaml ---

minio:
  image: registry.local/minio/minio
  imageTag: "RELEASE.2017-12-28T01-21-00Z"
  minioMc:
    image: registry.local/minio/mc
    tag: "RELEASE.2018-07-13T00-53-22Z"

registry:
  image:
    repository: registry.local/gitlab-org/build/cng/gitlab-container-registry
    tag: 'v3.86.1-gitlab'

postgresql:
  image:
    registry: registry.local
    repository: bitnami/postgresql
    tag: 15.3.0-debian-11-r0 # start with number to make checkConfig happy
  metrics:
    image:
      registry: registry.local
      repository: bitnami/postgres-exporter
      tag: 0.12.0-debian-11-r86

prometheus:
  server:
    image:
      repository: registry.local/prometheus/prometheus
      tag: v2.38.0
  configmapReload:
    prometheus:
      image:
        repository: registry.local/jimmidyson/configmap-reload
        tag: v0.5.0

redis:
  image:
    registry: registry.local
    repository: bitnami/redis
    tag: 6.2.7-debian-11-r11
  metrics:
    image:
      registry: registry.local
      repository: bitnami/redis-exporter
      tag: 1.43.0-debian-11-r4

# upgradeCheck: *custom
```

```bash
# Pull and push all images to local repo
nerdctl pull registry.gitlab.com/gitlab-org/build/cng/gitlab-kas:v16.6.0
nerdctl tag registry.gitlab.com/gitlab-org/build/cng/gitlab-kas:v16.6.0 registry.local/gitlab-org/build/cng/gitlab-kas:v16.6.0
nerdctl push --insecure-registry registry.local/gitlab-org/build/cng/gitlab-kas:v16.6.0

# Create secret for self signed sertificate for Gitlab Runner
kubectl get secret gitlab-wildcard-tls -n gitlab --template='{{ index .data "tls.crt" }}' | base64 -d > gitlab.crt
kubectl create secret generic gitlab-runner-certs -n gitlab --from-file=gitlab.gitlab.local.crt=gitlab.crt

# Install
helm upgrade --install gitlab gitlab/ --timeout 600s --create-namespace -n gitlab -f /home/master/projects/kubernetes_install/gitlab/values_changed.yaml

# Get Gitlab initial password
kubectl get secret gitlab-gitlab-initial-root-password -ojsonpath='{.data.password}' -n gitlab | base64 --decode ; echo
```


```bash
# Добавить сертификат в доверенные (на клиентской машине) в случае самоподписанного сертификата у сервера gitlab для того чтобы не было ошибки 
# git clone https://gitlab.gitlab.local/deploy/prometheus.git
# Cloning into 'prometheus'...
# fatal: unable to access 'https://gitlab.gitlab.local/deploy/prometheus.git/': server certificate verification failed. CAfile: none CRLfile: none
sudo apt-get update
sudo apt install libcurl4-openssl-dev
hostname=gitlab.gitlab.local
port=443
trust_cert_file_location=`curl-config --ca`

sudo bash -c "echo -n | openssl s_client -showcerts -connect $hostname:$port -servername $hostname  2>/dev/null  | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' >> $trust_cert_file_location"
```