# Monitoring

## Install Prometheus Stack

`Prometheus Operator`- это проект в экосистеме Kubernetes, который предоставляет автоматизированный и управляемый способ развертывания, настройки и масштабирования сервера мониторинга Prometheus и связанных компонентов в кластере Kubernetes.

Prometheus Operator управляет кастомными ресурсами Kubernetes CustomResourceDefinition (CRD), в кластере kubernetes.

CRD, это фактически расширение API Kubernetes, позволяя создавать и управлять своими собственными объектами через Kubernetes API сервер.

`Prometheus Operator CRD`

1. `Prometheus` - описывает установку Prometheus
2. `Alertmanager` - описывает установку Alertmanager
3. `ServiceMonitor` - Аналог service discovery (прописываем аннотации в поды чтобы он мониторился в Prometheus), описывает за какими сервисами нужно следить, какие порты должны использоваться в этом сервисе, как часто нужно делать scrape по какому endpoint находятся метрики... На основе этого он генерирует конфигурационный файл, для Prometheus Scraping.
4. `PodMonitor` - тоже самое только для pod, потому что не все поды имеют сервисы
5. `Probe` - Описывает список Ingress для добавления в мониторинг, например для BlackBox Exporter.
6. `PrometheusRule` - описывает набор Rules (Правил), которые будут добавлены в Prometheus Аналог ServiceMonitor
7. `AlertManagerConfig` - описывает набор Alerts которые будут добавлены в Prometheus

### Grafana

Чтобы загрузить новые dashboards или datasources в графану, нужно прописать `ConfigMaps` с определенными аннотациями. И контейнеры в pod с grafana отслеживают ConfigMaps с определенными аннотациями и монтируют эти ConfigMaps графане.

### Prometheus Про что важно не забыть

1. `Prometheus` нужно устанавливать минимум в 2 копии, потому что он StatefulSet
2. Нужно настраивать basic auth
3. retention size - ограничение размера данных которые он хранит.
4. Alertmanager - минимум в 3 копии
5. Alertmanager - authentication
6. Grafana - dashboards храним только в git и подгружаем их отдельно в виде configmaps.

### Установка

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community
helm pull prometheus-community/kube-prometheus-stack --untar
kubectl create ns prometheus-stack
# Create Secret for basic auth
htpasswd -c prometheus admin
kubectl create secret generic admin-basic-auth --from-file=prometheus -n prometheus-stack
# Проверка
kubectl get secrets -n prometheus-stack admin-basic-auth
```

```bash
docker pull quay.io/prometheus/alertmanager:v0.27.0
docker tag quay.io/prometheus/alertmanager:v0.27.0 registry.local/prometheus/alertmanager:v0.27.0
docker push registry.local/prometheus/alertmanager:v0.27.0
```

Создаем Storage class

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: fujitsu-dx200-sas
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: csi.vsphere.vmware.com
allowVolumeExpansion: true # Optional: only applicable to vSphere 7.0U1 and above
reclaimPolicy: Retain
parameters:
  datastoreurl: "ds:///vmfs/volumes/64ba41b0-a97c87e6-8742-28b4484c76d1/"
  # Должна быть создана заранее в VMWARE - Policies and Profiles - VM Storage Policies
  storagepolicyname: "Kuber-VMFS"
  csi.storage.k8s.io/fstype: "ext4"
```

```bash
kubectl create -f fujitsu-dx200-sas-storageclass.yaml
kubectl get storageclass
```

```bash
helm upgrade --install prometheus-stack /home/appuser/projects/prometheus/kube-prometheus-stack --namespace prometheus-stack --create-namespace -f /home/appuser/projects/prometheus/kube-prometheus-stack/changed_values.yaml
```

 Если ошибка Error: UPGRADE FAILED: failed to create resource: Internal error occurred: failed calling webhook "prometheusrulemutate.monitoring.coreos.com": failed to call webhook: Post "https://prometheus-stack-kube-prom-operator.prometheus-stack.svc:443/admission-prometheusrules/mutate?timeout=10s": tls: failed to verify certificate: x509: certificate signed by unknown authority то ставим в changed_values.yaml:

```yaml
prometheusOperator:

  ## Admission webhook support for PrometheusRules resources added in Prometheus Operator 0.30 can be enabled to prevent incorrectly formatted
  ## rules from making their way into prometheus and potentially preventing the container from starting
  ## Admission Webhooks - это механизм Kubernetes, который позволяет интеграциям (как Prometheus Operator) динамически модифицировать или проверять ресурсы Kubernetes перед их созданием или обновлением
  ## Prometheus Operator развертывает два дополнительных Pod - один для валидирующего Webhook и один для изменяющего Webhook.
  ## Kubernetes будет автоматически вызывать эти Webhook'и для любых ресурсов, связанных с Prometheus Operator (Prometheus, ServiceMonitor, etc).
  ## Эти Webhook'и помогают обеспечить правильность и согласованность конфигурации Prometheus.
  admissionWebhooks:
    ## Valid values: Fail, Ignore, IgnoreOnInstallOnly
    ## IgnoreOnInstallOnly - If Release.IsInstall returns "true", set "Ignore" otherwise "Fail"
    # Настройка admissionWebhooks с failurePolicy: "Fail" в Prometheus Operator обеспечивает дополнительный уровень проверки для ресурсов PrometheusRules, 
    # помогая предотвратить внесение неправильно отформатированных правил, которые могут нарушить работу Prometheus.
    # Изменил значение
    # "Fail" - Если Webhook недоступен или возвращает ошибку, Kubernetes откажет в создании или обновлении ресурса.
    # Это гарантирует, что ресурсы будут проверены Webhook'ом перед применением.
    # Делаем Ignore если проблемы при развертывании Error: UPGRADE FAILED: failed to create resource: Internal error occurred: failed calling webhook "prometheusrulemutate.monitoring.coreos.com": failed to call webhook: Post "https://prometheus-stack-kube-prom-operator.prometheus-stack.svc:443/admission-prometheusrules/mutate?timeout=10s": tls: failed to verify certificate: x509: certificate signed by unknown authority
    # Лучше ставить Fail
    failurePolicy: "Ignore"
```

## Установка Node-Exporter

```bash
ansible-playbook node_exporter.yaml --private-key /home/appuser/.ssh/id_ed25519 --limit SZTU-SC2012 --ask-become-pass
```

### Установка секрета для node_exporter basic_auth

```bash
kubectl create secret generic node-exporter-secret \
  --from-literal=username=myuser \
  --from-literal=password=mypassword \
  -n prometheus-stack```
```

## Monitoring vCenter

### Установка influxdb

Создать secret

```bash
kubectl apply -f /home/appuser/projects/prometheus/influxdb/influxdb_secrets.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: influxdb-secrets
  namespace: influxdb  # Убедитесь, что это правильный namespace
type: Opaque
# Перевести в Base64: echo -n 'your_value' | base64
# Расшифровать: echo 'U29tZSBzdHJpbmc=' | base64 --decode
data:
  influxdb_token: "" # Base64-encoded токен
  influxdb_user: "" # Base64-encoded username
  influxdb_password: "" # Base64-encoded password
immutable: false  # Секрет может быть изменен
```

```bash
helm upgrade --install influxdb /home/appuser/projects/prometheus/influxdb/influxdb2 --namespace influxdb --create-namespace -f /home/appuser/projects/prometheus/influxdb/vcenter_changed_values.yaml
```

```bash
docker pull docker.io/library/influxdb:2.7.4-alpine
docker tag docker.io/library/influxdb:2.7.4-alpine registry.local/library/influxdb:2.7.4-alpine
docker push registry.local/library/influxdb:2.7.4-alpine
```

### Подготовка vCenter

Нужно установить config.vpxd.stats.maxQueryMetrics на более высокое значение для сбора метрик чтобы не было ошибок в логах контейнера telegraf

1. Заходим в vCenter - Переходим на верхний уровень (vCenter Server) - Configure - Advanced Settings - Edit Settings - Создаем значение если не создано config.vpxd.stats.maxQueryMetrics выставляем например 1024 (-1 - не ограничено)

2. Подключаемся по ssh к нашему vCenter под root

```bash
Command> shell
cd /usr/lib/vmware-perfcharts/tc-instance/webapps/statsreport/WEB-INF
chmod web.xml 644
vim web.xml
# Прописываем новое значение
```

```conf
<context-param>
<description>Specify the maximum query size (number of metrics)for a single report. Non-positive values are ignored.</description>
<param-name>maxQuerySize</param-name>
<param-value>1024</param-value>
</context-param>
```

```bash
chmod 444 web.xml
# Перезапускаем службу
cd /bin
service-control --list
service-control --stop vmware-perfcharts
service-control --start vmware-perfcharts
```

Создать secret

```bash
kubectl apply -f /home/appuser/projects/prometheus/telegraf/telegraf-tokens.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: telegraf-tokens
  namespace: telegraf  # Убедитесь, что это правильный namespace
type: Opaque
# Перевести в Base64: echo -n 'your_value' | base64
# Расшифровать: echo 'U29tZSBzdHJpbmc=' | base64 --decode
data:
  influxdb_token: "" # Base64-encoded токен
  vsphere_username: "" # Base64-encoded username
  vsphere_password: "" #Base64-encoded password
immutable: false  # Секрет может быть изменен
```

### Установка telegraf

```bash
docker pull docker.io/library/telegraf:1.32-alpine
docker tag docker.io/library/telegraf:1.32-alpine registry.local/library/telegraf:1.32-alpine
docker push registry.local/library/telegraf:1.32-alpine
```

```bash
helm upgrade --install telegraf /home/appuser/projects/prometheus/telegraf/telegraf --namespace telegraf --create-namespace -f /home/appuser/projects/prometheus/telegraf/changed_values.yaml
```
