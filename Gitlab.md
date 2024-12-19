# Gitlab

## Gitlab Install

### Change Ingress Options

Посмотреть как называется service gitlab

add --set tcp.22="gitlab/gitlab-gitlab-shell:22"  

<https://kubernetes.github.io/ingress-nginx/deploy/>

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

### Set reclaim Policy to Storage Class

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
  # Должна быть создана заранее в VMWARE - Policies and Profiles - VM Storage Policies
  storagepolicyname: "Kuber-VMFS"
  csi.storage.k8s.io/fstype: ext4
```

### Download Chart and install

```bash
# Download Chart Locally
helm pull gitlab/gitlab --untar
# Create values_changed.yaml
```

```yaml
# Need to set certmanager-issuer.email before template
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

# Create secret for self signed certificate for Gitlab Runner
# Если до этого использовался другой домен то нужно перед обновлением чарта удалить два секрета
# gitlab-wildcard-tls и gitlab-wildcard-tls-chain и только после этого создавать секрет
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

## Gitlab Runner Install (Docker with Req)

### Create docker file

create files:  
kubernetes_install/gitlab/runner/dockerfile  
kubernetes_install/gitlab/runner/entrypoint  
kubernetes_install/gitlab/runner/ca.crt  
kubernetes_install/gitlab/runner/gitlab-runner_amd64.deb  

```dockerfile
# Аргумент который может быть переопределен, BASE_IMAGE - имя переменной, значение по умолчанию
ARG BASE_IMAGE=ubuntu:22.04

# Определяем базовый образ и название этапа (builder)
FROM $BASE_IMAGE AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Установка базовых зависимостей
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        git git-lfs \
        wget \
        tzdata \
        openssh-client \
        smbclient \
        python3 \
        python3-pip \
        python3-venv \
        build-essential \
        libssl-dev \
        libffi-dev \
        python3-dev \
        dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Добавляем здесь сертификат и обновляем сертификаты
# В случае самоподписанного сертификата получаем его так
# openssl s_client -showcerts -connect gitlab.gitlab.local:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > ca.crt
COPY ca.crt /usr/local/share/ca-certificates/gitlab.crt
RUN update-ca-certificates

# Установка Python пакетов
RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir smbprotocol

# Установка GitLab Runner (пример для amd64)
COPY gitlab-runner_amd64.deb /tmp/
RUN dpkg -i /tmp/gitlab-runner_amd64.deb && \
    apt-get update && \
    apt-get -f install -y && \
    rm -rf /var/lib/apt/lists/* && \
    rm /tmp/gitlab-runner_amd64.deb && \
    rm -rf /etc/gitlab-runner/.runner_system_id

FROM $BASE_IMAGE

# Копируем все файлы из предыдущей стадии сборки builder в текущий контейнер
# Многоступенчатая сборка помогает уменьшить размер финального образа
COPY --from=builder / /
# Копирует файл entrypoint из текущего контекста сборки в корневую директорию контейнера
COPY --chmod=755 entrypoint /

# Создание рабочих директорий
RUN mkdir -p /etc/gitlab-runner /home/gitlab-runner && \
    chown -R gitlab-runner:gitlab-runner /home/gitlab-runner

# Настройка сигнала остановки позволяет процессу корректно завершить работу
STOPSIGNAL SIGQUIT
# При запуске контейнера docker либо автоматически создает тома либо можем указать явно при запуске куда монтировать 
# docker run -v /path/on/host/etc/gitlab-runner:/etc/gitlab-runner -v /path/on/host/home/gitlab-runner:/home/gitlab-runner my-gitlab-runner-image
VOLUME ["/etc/gitlab-runner", "/home/gitlab-runner"]
# ENTRYPOINT какой процесс будет запускаться при старте контейнера (Выполняется всегда)
# dumb-init используется для того, чтобы управлять процессами и сигналами в контейнере корректно, выполняя роль простого инициализатора
# /entrypoint это скрипт или исполняемый файл (который мы предварительно скопировали), который запускается сразу после старта dumb-init
ENTRYPOINT ["/usr/bin/dumb-init", "/entrypoint"]
# CMD может быть переопределена
# run - команда для запуска runner'а в режиме службы
# --user=gitlab-runner - указывает, от какого пользователя запускать процесс
# --working-directory=/home/gitlab-runner - определяет рабочую директорию
CMD ["run", "--user=gitlab-runner", "--working-directory=/home/gitlab-runner"]
```

entrypoint:

```bash
#!/bin/bash

# gitlab-runner data directory
# Определение путей к конфигурационным файлам
DATA_DIR="/etc/gitlab-runner"
# Если CONFIG_FILE не задан через переменную окружения, использует значение по умолчанию
CONFIG_FILE=${CONFIG_FILE:-$DATA_DIR/config.toml}

# custom certificate authority path
# Пути к сертификатам
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-$DATA_DIR/certs/ca.crt} # Путь к пользовательскому сертификату
LOCAL_CA_PATH="/usr/local/share/ca-certificates/ca.crt" # Системный путь к сертификату

# Функция обновления сертификатов
update_ca() {
  echo "Updating CA certificates..."
  # Копируем пользовательский сертификат в системную директорию
  cp "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}"
  # Обновляем системные сертификаты
  update-ca-certificates --fresh >/dev/null
}

# Проверяем наличие пользовательского сертификата
if [ -f "${CA_CERTIFICATES_PATH}" ]; then
  # Сравниваем текущий и новый сертификат
  # Если они различаются (или текущего нет), обновляем сертификаты
  # update the ca if the custom ca is different than the current
  cmp --silent "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}" || update_ca
fi

# Запускаем gitlab-runner со всеми переданными аргументами
# launch gitlab-runner passing all arguments
# эти аргументы берутся из команды CMD в Dockerfile или из аргументов, которые вы передаете при запуске контейнера
# docker run gitlab-runner В этом случае: "$@" получит аргументы из CMD
# итоговая команда будет exec gitlab-runner run --user=gitlab-runner --working-directory=/home/gitlab-runner
exec gitlab-runner "$@"
```

### Build docker image

```bash
wget "https://gitlab-runner-downloads.s3.amazonaws.com/v17.5.1/deb/gitlab-runner_amd64.deb"
docker build -t gitlab-runner-custom:v1.1 .
docker tag 6854625da496 registry.local/library/gitlab-runner-custom:v1.1
docker push registry.local/library/gitlab-runner-custom:v1.1
```

### Change Gitlab values.yaml

```bash
kubectl get secret gitlab-wildcard-tls -n gitlab --template='{{ index .data "tls.crt" }}' | base64 -d > gitlab.crt
kubectl create secret generic gitlab-runner-certs -n gitlab --from-file=gitlab.gitlab.local.crt=gitlab.crt
```

```yaml
gitlab-runner:
  gitlabUrl: https://gitlab.gitlab.local
  certsSecretName: gitlab-runner-certs
  securityContext:
    allowPrivilegeEscalation: true
    privileged: true
  runners:
    privileged: true
    config: |
      [[runners]]
        [runners.kubernetes]
          namespace = "{{.Release.Namespace}}"
          image = "registry.local/library/gitlab-runner-custom:v1.1"
          helper_image = "registry.local/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-f5da3c5a"
  image:
    registry: registry.local
    image: gitlab-org/gitlab-runner
  # Прописываем в /etc/hosts pod наш gitlab сервер
  ## list of hosts and IPs that will be injected into the pod's hosts file
  hostAliases:
    - ip: "1.1.1.1"
      hostnames:
      - "gitlab.gitlab.local"
```

```bash
helm upgrade --install gitlab gitlab/ --timeout 600s --create-namespace -n gitlab -f /home/appuser/projects/prometheus/gitlab/values_changed.yaml
```

### Ldap Integration

```yaml
global:
  appConfig:
    ldap:
      servers:
        main:
          label: 'LDAP'
          host: 'abc.contoso.com'
          port: 389
          uid: 'sAMAccountName'
          bind_dn: 'CN=admin,OU=admin,DC=abc,DC=contoso,DC=com'
          # Создаем секрет kubectl create secret generic ldap-pas --from-literal=password='your-password' -n gitlab
          password:
            secret: ldap-pas
            key: password
          encryption: 'plain'
          verify_certificates: false
          timeout: 10
          active_directory: true
          user_filter: '(memberOf=CN=gitlabgroup,OU=admins,DC=abc,DC=contoso,DC=com)'
          base: 'dc=abc,dc=contoso,dc=com'
          lowercase_usernames: false
          retry_empty_result_with_codes: [80]
          allow_username_or_email_login: false
          block_auto_created_users: false
```