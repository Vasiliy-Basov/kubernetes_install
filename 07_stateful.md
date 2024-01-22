# Stateful приложения

Если Stateful запущен в несколько инстансов
- Случайные имена которые задает ReplicaSet (случайный суффикс)
- Одинаковый конфиг для всех подов
- Один том на все поды
- Поды создаются в произвольном порядке (могут быть проблемы инициализации при первоначальном запуске)
- Нет прямого доступа к поду, только доступ к случайному поду через сервис

## Statefulset
- Стабильные имена (name-0, name-1, name-2)
- Постоянные уникальные хранилища (volumeClaimTemplates) - тогда для каждого пода создается свой собственный PersistentVolumeClaim 
Если pod был удален и создан новый с таким же индексом то к этому поду будет подключен уже существующий том с сохраненными данными
Что бы обновить информацию нужно удалять старый pvc вручную
- Упорядоченное создание и удаление. Стратегия изменения количества подов указывается в поле podManagementPolicy 
Есть две стратегии: OrderedReady или Parallel
- Упорядоченное обновление - поле updateStrategy
onDelete - устаревшая (при обновлении манифеста ничего не происходит), для обновления пода его надо удалить вручную
rolllingUpdate (по умолчанию) - при обновлении начинается обновление подов по одному начиная с подов с наибольшим индексом.
partition - можно указать количество подов которые не будут затронуты обновлением (Если указываем 3 то поды 0,1,2 yt будут обновляться)
- Отправка запроса на определенный pod - headless service - это сервис у которого в поле clusterIp: none. Для таких сервисов не создаются правила а iptables, но создаются dns записи. 

## Приложения и баз данных для облаков
- Relational
Percona XtraDB Cluster + MariaDB Foundation - Это MySQL

- NoSQL
mongoDB

- In-memory db
redis, Memcashe

- Message Queue
RabbitMQ

- Search engine
elasticsearch

- Service Discovery
etcd  
consul  
ZooKeeper

# Install RabbitMQ
## Скачиваем чарт локально
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo bitnami/rabbitmq
# Меняем в .\kubernetes_install\rabbitmq\changed_values.yaml нужные нам values ingress, password etc
helm upgrade --install --wait rabbitmq --create-namespace --namespace rabbitmq ./rabbitmq/rabbitmq -f ./rabbitmq/changed_values.yaml
# Если нету StorageClass и PersistentVolume то создаем (Можно локально)
```

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

Прописываем в /etc/hosts 192.168.0.151 rabbitmq.local
Проверяем

Если у нас несколько реплик, то удаление пода, не должно повлиять на работу кластера. Он должен перезапуститься с помощью StatefulSet.

# PostgreSQL
Так как PostgreSQL не Cloud Native для него используются операторы, которые следят за состоянием кластера и взаимодействуют с пользователем

Оператор для PostgreSQL - Stolon, Это Claud Native Manager для PostgreSQL. Создает кластер не только в kubernetes но и в других системах оркестрации.

Особенности
- Потоковая репликация PostgreSQL
- Интегрируется с kubernetes
- Хранит свое состояние в etcd, consul или kubernetes API
- Синхронная и асинхронная репликация
- Установка кластера за минуты
- Умеет делать PointinTimeRecovery
- Автоматически настраивает новые члены кластера
- Использует pg_rewind для быстрой повторной синхронизации

Подобная конфигурация позволяет хорошо автоматизировать кластер PostgreSQL

# CockroachDB

