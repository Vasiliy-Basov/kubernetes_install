# Сети Kubernetes

Построение сети на узле кластера
![oidc](/pics/node-network.png)

bridge - это аналог коммутатора  
На каждый узел выделяется сеть ip адресов

Трафик на другие узлы направляется в сеть кластера  
Например все узлы шлют трафик на центральный маршрутизатор  


## CNI - Container network interface

Стандарт конфигурации сетевых интерфейсов для linux контейнеров

![oidc](/pics/cni.png)

Плагин cni отвечает за 
- добавление интерфейса в сетевом пространстве имен контейнера 
- Назначение ip адресов
- настройку маршрутизации

Какой именно плагин использовать задается в ключах kubelet

Network plugin - это не название cni plugin а тип plugin  
--network-plugin=kubenet # только для одной ноды
--network-plugin=cni # основной режим

При запуске kubelet указываются опции
--cni-bin-dir=/opt/cni/bin - каталог в котором лежат сетевые плагины
--cni-conf-dir=/etc/cni/net.d - каталог в котором лежат настройки сетевых плагинов

4 самых популярных плагина:
![oidc](/pics/netplugins.png)

### Flannel 
Самый простой и быстрый
Backends для flannel

- host-gw - таблицы маршрутизации на узлах в которых указывается какие поды на каких нодах
- VxLAN - если узлы находятся в разных сетях (L3) - туннели
- AWS VPC, GCE VPC, Ali VPC - для облачных провайдеров
- IpSec - Шифрованные туннели - самый медленный способ

### Calico

Хранит свои настройки в etcd или в kubernetes API

- Использует BGP для настройки роутинга между узлами
- Динамически выделяет сети ip адресов на узлы
- Network Policies - кластерный firewall
- IPIP tunnels - если узлы находятся в разных сетях - для L3 сетей

calicoctl - утилита для настройки плагина

Например:  
Посмотреть какая сеть выделена для подов
```bash
calicoctl get ippool -o yaml
```
ipipMode: CrossSubnet - указываем в каких случаях нужно строить тупели между узлами  
CrossSubnet - строить туннели только в тех случаях когда они нужны  

```bash
calicoctl get nodes -o wide
```
Если сети узлов находятся в одной сети то между ними туннели не строятся

### Weave Net

Шифрование трафика уменьшает скорость сети в 10 - 15 раз

## Ставим сетевой плагин

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
            # Это универсальный метод, не нужно указывать подсеть или интерфейс.
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

## Проверяем, что всё заработало

```bash
kubectl get node
kubectl get po -A
```

# Network Policy Сетевые политики
Запрещено все что не разрешено  
Пока сетевых политик нету все работает  
Как только мы создаем сетевую политику сражу запрещается весь трафик к тому объекту к которому мы эту политику применим.  

Если есть сетевая политика которая разрешает доступ от одного пода к другому то эта политика будет запрещать доступ к поду от всех остальных подов.  

## Входящий трафик
### Запрет трафика
Политика которая запрещает любой трафик который идет в поды в namespace base
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: default-deny
  namespace: base
spec:
  podSelector:
    # {} - это выбирает все поды (пустая метка)
    matchLabels: {}
```

У calico также есть свой набор network policy в CRD calico


### Разрешение всего трафика из пода в под 
Политика разрешает трафик из pod access в pod base в одном namespace (политика применяется к поду с меткой run=base к остальным подам политика не будет применятся и трафик будет разрешен)
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: access-bd
  namespace: base
spec:
  # Действует на поды с меткой run=base
  podSelector:
    matchLabels:
      run: base
  # `- from:` разрешаем трафик из пода с меткой run=access
  # `ingress:` — описываем список правил для входящего в поды трафика
  ingress:
  - from:
      - podSelector:
          matchLabels:
            run: access
```

Посмотреть метки подов  
```bash
kubectl get pod -n base -o wide --show-labels
```

### Разрешение конкретного трафика из пода в под
Разрешаем доступ только к 22 порту
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: access-bd
  namespace: base
spec:
  podSelector:
    matchLabels:
      run: base
  ingress:
  # Информация по разрешенному трафику (протокол и порт)
  - ports:
     - port: 22
       protocol: TCP
    from:
      - podSelector:
          matchLabels:
            run: access
```

ping не будет работать Проверка curl из контейнера access
```bash
kubectl -n base exec -it access -- bash
curl 10.244.164.134:22
```

### Разрешение трафика из другого namespace
Разрешение на доступ трафика из другого namespace  
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: access-bd-prod
  namespace: base
spec:
  podSelector:
    matchLabels:
      run: base
  ingress:
  - ports:
      - port: 22
        protocol: TCP
    from:
      - podSelector:
          matchLabels:
            run: access
        # Выбираем поды из какого namespace будут иметь доступ
        # namespace тоже должен иметь метку
        # создать метку для namespace: kubectl label ns prod type=prod
        namespaceSelector:
          matchLabels:
            type: prod
```

## Внимание !
Обратите внимание на синтаксис yaml'а:
Если мы укажем вот так:
```yaml
  - from:
      - podSelector:
          matchLabels:
            run: access
      - namespaceSelector:
          matchLabels:
            type: prod
```

То это будет список из двух элементов, правила выборки будут объединены как логическое ИЛИ. Доступ будет разрешен из pod'ов с меткой `run=access` в том же namespace, а также для ВСЕХ pod'ов из namespace с меткой `prod`.

А вот такой манифест, отличающийся только одним минусом:
```yaml
  - from:
    - podSelector:
        matchLabels:
          run: access
      namespaceSelector:
        matchLabels:
           type: prod
```

Представляет собой один элемент списка, и будут выбраны объекты, которые удовлетворяют всем селекторам, то есть pod'ы с меткой `access` из namespace с меткой `prod`.

## Фильтрация исходящего трафика

### Запрещаем доступ с prod в интернет

Разрешено:
- внутри кластера
- 8.8.8.8
- 1.1.1.1
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-prod
  namespace: prod
spec:
  # Обязательно прописываем policyTypes потому что по умолчанию примениться еще и ingress если у нас не указано явно policyTypes
  policyTypes:
    - Egress
  podSelector:
    matchLabels: {}
  egress:
  - to:
    - podSelector:
       matchLabels: {}
      namespaceSelector:
       matchLabels: {}
    - ipBlock:
       cidr: 8.8.8.8/32
    - ipBlock:
       cidr: 1.1.1.1/32
```

### Запрещаем доступ с prod в интернет c указанием разрешенных портов и протоколов

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: deny-prod
  namespace: prod
spec:
  podSelector:
    matchLabels: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
       matchLabels: {}
      namespaceSelector:
       matchLabels: {}
  - to:
    - ipBlock:
       cidr: 8.8.8.8/32
    - ipBlock:
       cidr: 1.1.1.1/32
    ports:
      - port: 53
        protocol: UDP
```

## Посмотреть все сетевые политики

```bash
kubectl get networkpolicies. -n base
```

Рассмотрим, каким образом указываются разрешенные соединения в спецификациях `Network Policy:`

Сначала указываем тип `Ingress` и/или `Egress`, потом в разделах `ingress:` и/или `egress:` указывается, кому откуда и/или куда разрешен трафик, а также какой именно трафик разрешен: порт и протокол.
```yaml
spec:
  policyTypes:
  - Ingress
  - Egress
  - Ingress,Egress
#- правила для входящего трафика
  ingress: 
    - ports:
       - port: 80
         protocol: TCP или UDP или SCTP
    - from:
       - ipBlock
          cidr: диапазон разрешенных адресов
          except: список вырезанных кусочков
       - namespaceSelector:
           matchLabels:
       - podSelector:
           matchLabels:
# - правила для исходящего трафика
  egress: 
    - ports:
    - to:
```
Если в элементе списка указан только `ports:` — значит, трафик на этот порт разрешен всем.

Pods которые запущены в режиме host network. Внутри этого пода сетевой интерфейс узла. У этого пода адрес nod-ы. Поэтому даже если мы пропишем в podselector метку такого пода правило не сработает. Нужно прописывать ip адреса узлов на которых такие поды запущены в ipBlock. Например ingress nginx.
