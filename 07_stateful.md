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

## Сначала создаем локальные постоянные тома  
Предварительно нужно создать нужные папки на нужных нодах  
\kubernetes_install\cockroachdb
```bash
kubectl apply -f sc-cockroach.yaml
kubectl apply -f pv-local-cockroach
kubectl get pv

kubectl create ns cockroachdb
# Устанавливаем чарт из локальной папки
helm repo add cockroachdb https://charts.cockroachdb.com/
helm repo update
helm pull cockroachdb/cockroachdb --untar
helm upgrade --install cockroachdb ./cockroachdb/ --namespace cockroachdb --create-namespace -f changed_values.yaml
kubectl get po -n cockroachdb
kubectl get pv
kubectl get pvc -n cockroachdb

```

### Запускаем SQL-клиент для Cockroachdb и подключаемся им в Service
```bash
# 1) Сперва создаем Pod с клиентом
kubectl create -f client-secure.yaml -n cockroachdb
# 2) Затем подключаемся через этот Pod клиента к CockroachDB:
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public
# 3) Создадим базу данных и таблицу там
CREATE DATABASE bank;

CREATE TABLE bank.accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      balance DECIMAL
  );

INSERT INTO bank.accounts (balance)
  VALUES
      (1000.50), (20000), (380), (500), (55000);

SELECT * FROM bank.accounts;

quit
# 4) Проверим, действительно ли наши транзакции применились на других нодах. А также сразу проверим возможность писать в разные ноды. Подключимся к какой-нибудь конкретной ноде Cockroachdb:
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-0.cockroachdb
# 5) Смотрим записи в табличке
SELECT * FROM bank.accounts;
# 6) Добавляем еще одну запись в табличку
INSERT INTO bank.accounts (balance) VALUES (77777);

SELECT * FROM bank.accounts;

quit
# 7) Теперь подключимся к другой ноде Cockroachdb:
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-1.cockroachdb
# 8) Смотрим что ранее созданные данные там есть и добавляем еще одну строчку для проверки возможности записи
SELECT * FROM bank.accounts;

INSERT INTO bank.accounts (balance) VALUES (99999);

quit
```

### Теперь потестим восстановление Cockroachdb
```bash
# 1) Для этого удалим Pod Statefulset'а и затем проверим данные на нем
kubectl delete po -n cockroachdb cockroachdb-2
# 2) Ждем поднятия Pod'а
kubectl get po -n cockroachdb -w
# 3) После поднятия заходим клиентом на эту ноду и проверяем данные
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-2.cockroachdb

SELECT * FROM bank.accounts;

quit
```

### Disaster Recovery. Попробуем теперь уничтожить реплики CockroachDB совсем и посмотрим какую недоступность это вызывает

1) Сохраняем Statefulset в файл и удаляем его, оставляя Pod'ы работать:

```bash
kubectl get statefulset -n cockroachdb cockroachdb -o yaml > sts.yaml

kubectl delete sts -n cockroachdb cockroachdb --cascade=orphan
```

2) Запускаем наше демо-приложение, которое будет каждую секунду обращаться в базу. Смотрим его логи

```bash
kubectl create -f demo-disaster.yaml -n cockroachdb

kubectl logs -n cockroachdb cockroachdb-client-disaster -f
```

3) Далее будет удобнее работать, открыв вторую консоль. В одной у нас будут показываться логи демо-приложения, а во второй будем производить действия. Удаляем один Pod и смотрим что происходит в логах приложения параллельно: 

```bash
kubectl delete po -n cockroachdb cockroachdb-0

# Смотрим во второй консоли логи демо-приложения
```

4) Делаем по хардкору. Удаляем еще один Pod и параллельно смотрим логи демо-приложения:

```bash
kubectl delete po -n cockroachdb cockroachdb-1

# Смотрим во второй консоли логи демо-приложения
```

> Видим, что демо-приложение перестало выдавать инфу о cockroachdb, а последний оставшийся Pod висит в 0/1. Мы уперлись в фактор репликации.
 
5) Пробуем вернуть все как было, возвращаем Statefulset, смотрим на поднятие реплик, целостность данных и логи демо-приложения:

```bash
kubectl apply -f sts.yaml -n cockroachdb

# Смотрим во второй консоли логи демо-приложения
```

> После поднятия хотя бы одного пода демо-приложение снова заработало, данные стали писаться/читаться. 

6) Проверим нашу ранее созданную табличку:

```bash
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public

SELECT * FROM bank.accounts;

quit
```
  
**ДОМАШНЯЯ РАБОТА:** 
- Познакомиться с админкой Cockroachdb. Для этого нужно подправить `values.yaml` чарта и включить Ingress в нем, не забыв указать правильное доменное имя. Либо написать свой Ingress и отправить его в CockroachDB.
- Создать пользователя для админки:

```
kubectl exec -it cockroachdb-client-secure -n cockroachdb -- ./cockroach sql --certs-dir=/cockroach-certs --host=cockroachdb-public

CREATE USER slurm WITH PASSWORD 'slurmpass';

quit
```

- Заходим в режиме инкогнито через браузер по адресу вашего Ingress'а (в браузере "Соглашаемся с риском", возможно несколько раз придется согласится пока админка откроется). 
- Используем ранее созданного юзера для авторизации
