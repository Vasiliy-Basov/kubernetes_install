# Взлом Kubernetes

C:\Films\Kubernetes Мега\megakube-main\4.secure-and-highlyavailable-apps\psp

```bash
# Cоздаем тестового пользователя
kubectl create serviceaccount user --namespace=default
kubectl create rolebinding user --clusterrole=edit --serviceaccount=default:user --namespace=default
kubectl create rolebinding user --clusterrole=edit --serviceaccount=default:user --namespace=dev
# Проверяем права созданного пользователя
kubectl get po --as=system:serviceaccount:default:user --all-namespaces
# Куб должен запрещать просмотр всех Pod'ов во всем кластере
```

hackers-pod.yaml
```yaml
---
apiVersion: v1
kind: Pod
metadata:
  name: hackers-pod
spec:
  containers:
  - command: ["/bin/bash", "-c", "sleep 100000"]
    image: debian
    name: hackers-pod
    volumeMounts:
    - mountPath: /host
      name: host
  hostNetwork: true
  hostPID: true
  tolerations:
  - effect: NoSchedule
    operator: Exists
  nodeSelector:
    node-role.kubernetes.io/control-plane: ""
  volumes:
  - hostPath:
      path: /
      type: Directory
    name: host
```

```bash
# Пробуем хакнуть ограничения
kubectl create -f hackers-pod.yaml --as=system:serviceaccount:default:user --namespace=default
kubectl get pod
# Заходим внутрь
kubectl exec -t -i hackers-pod --as=system:serviceaccount:default:user bash
# Радуемся полученному доступу к сертификатам кластера
cat /host/etc/kubernetes/admin.conf
# Удаляем
kubectl delete -f hackers-pod.yaml
```

В результате мы получаем доступ админа от любого пользователя.

# Pod Security Policies (PSP) Removed from 1.25

Контролирует аспекты безопасности в описании подов

PSP - Это Admission controller plugin который по умолчанию выключен.

При включении плагина PSP запрещает запуск всех подов которые не проходят валидацию. Уже запущенны поды затронуты не будут.

Поэтому сначала создаем правила и только потом включаем плагин.

Создаем два rbac один будет использовать psp с именем system другой psp с именем default

Правила  
rbac-default.yaml
```yaml
---
# Распространяется на весь кластер
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: default-psp
# Мы разрешаем использовать podsecurity policy с именем default
rules:
  - apiGroups:
      - policy
    resources:
      - podsecuritypolicies
    verbs:
      - use
    resourceNames:
      - default
# Настраиваем что все кто авторизован в кластере будут проходить через rbac default-psp
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: default-psp
roleRef:
  kind: ClusterRole
  name: default-psp
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    apiGroup: rbac.authorization.k8s.io
    # Все кто авторизован в кластере
    name: system:authenticated
```
Дефолтная политика распространяемая на весь кластер:  
psp-default.yaml
```yaml
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: default
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: 'runtime/default'
    seccomp.security.alpha.kubernetes.io/defaultProfileName:  'runtime/default'
spec:
  # Нельзя запускать привилегированные поды
  privileged: false
  hostNetwork: false
  hostIPC: false
  hostPID: false
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  # Указываем какие volume мы можем использовать в поде
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
```

```yaml
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system-psp
rules:
  - apiGroups:
      - policy
    resources:
      - podsecuritypolicies
    verbs:
      - use
    resourceNames:
      - system
# Доступно Только в рамках namespace kube-system (RoleBinding)
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: system-psp
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: system-psp
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: Group
    apiGroup: rbac.authorization.k8s.io
    name: system:authenticated
```

psp-system.yaml - Все разрешено
```yaml
---
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: system
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  privileged: true
  hostNetwork: true
  hostPID: true
  hostIPC: true
  hostPorts:
    - min: 0
      max: 65535
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
    - '*'
  allowedCapabilities:
    - '*'
```

## Pod Security Admission replace PSP

https://www.youtube.com/watch?v=JYM7mSShfp0

Включено по умолчанию с версии 1.23
Это Admission controller plugin

![oidc](/pics/psa.png)

Ограничения применяются на уровне namespace

Мы можем применять политики ограничения используя метки (labels) на namespace
```bash
kubectl get ns --show-labels
```

Создаем namespace c определенными метками
```bash
# The per-mode level label indicates which policy level to apply for the mode.
# MODE must be one of `enforce`, `audit`, or `warn`.
# LEVEL must be one of `privileged`, `baseline`, or `restricted`.
# pod-security.kubernetes.io/<MODE>: <LEVEL>

# Optional: per-mode version label that can be used to pin the policy to the
# version that shipped with a given Kubernetes minor version (for example v1.29).
# MODE must be one of `enforce`, `audit`, or `warn`.
# VERSION must be a valid Kubernetes minor version, or `latest`.
# pod-security.kubernetes.io/<MODE>-version: <VERSION>
kind: Namespace
metadata:
  name: my-privileged-namespace
  labels:
    pod-security.kubernetes.io/enforce: privileged
    # Какую версию ограничений применять (из какой версии кластера например 1.27)
    pod-security.kubernetes.io/enforce-version: latest
```

Также может быть применен на кластерном уровне
используя AdmissionConfigFile

https://kubernetes.io/docs/concepts/security/pod-security-standards/
Какие бывают уровни
- Privileged - Без ограничений
- Baseline - минимальные ограничения
- Restricted - Сильные ограничения

### Pod Security Modes
- Enforce - Это правило и оно будет применятся Если не соответствует этому правилу pod creation будет rejected
- Audit - Записывает такие события в audit.log но позволяет создавать pods. Чтобы использовать audit мы должны активировать аудит в кластере. `kubectl describe po -n kube-system kube-apiserver-kub-master-01`
![oidc](/pics/audit.png)

audit.yaml
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages:
  - "RequestReceived"
rules:
  - level: Request
    resources:
      - group: "" # core API group
        resources: ["pods"]
    namespaces: ["dev"]
  - level: RequestResponse
    resources:
      - group: "" # core API group
        resources: ["pods"]
      - group: "apps"
        resources: ["deployments"]
    namespaces: ["dev"]
    verbs: ["create", "update"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["pods/log", "pods/status"]
    namespaces: ["dev"]
```
- Warn - Выдает warning но все разрешает.



### Шаги по созданию политик
![oidc](/pics/psa-create-steps.png)

```yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: PodSecurity
  configuration:
    apiVersion: pod-security.admission.config.k8s.io/v1 # see compatibility note
    kind: PodSecurityConfiguration
    # Defaults applied when a mode label is not set.
    #
    # Level label values must be one of:
    # - "privileged" (default)
    # - "baseline"
    # - "restricted"
    #
    # Version label values must be one of:
    # - "latest" (default) 
    # - specific version like "v1.29"
    defaults:
      enforce: "privileged"
      enforce-version: "latest"
      audit: "privileged"
      audit-version: "latest"
      warn: "privileged"
      warn-version: "latest"
    # Исключения
    exemptions:
      # Array of authenticated usernames to exempt.
      usernames: []
      # Array of runtime class names to exempt.
      runtimeClasses: []
      # Array of namespaces to exempt.
      namespaces: []
```

```yaml
# Создаем namespace c ограничениями по созданию подов
kind: Namespace
metadata:
  name: dev
  labels:
    pod-security.kubernetes.io/enforce: baseline
    # Какую версию ограничений применять (из какой версии кластера например 1.27)
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    # Какую версию ограничений применять (из какой версии кластера например 1.27)
    pod-security.kubernetes.io/audit-version: latest
    pod-security.kubernetes.io/warn: restricted
    # Какую версию ограничений применять (из какой версии кластера например 1.27)
    pod-security.kubernetes.io/warn-version: latest

```

Применить к существующему namespace
```bash
# проверка
kubectl label ns dev pod-security.kubernetes.io/enforce=baseline --dry-run=server --overwrite
# применение
kubectl label ns dev pod-security.kubernetes.io/enforce=baseline
# Проверка
kubectl create -f hackers-pod.yaml -n dev
Error from server (Forbidden): error when creating "hackers-pod.yaml": pods "hackers-pod" is forbidden: violates PodSecurity "baseline:latest": host namespaces (hostNetwork=true, hostPID=true), hostPath volumes (volume "host")
# Удаление метки
kubectl label namespace dev pod-security.kubernetes.io/enforce-
```

# Pod Disruption Budget

```bash
cd "C:\Films\Kubernetes Мега\megakube-main\4.secure-and-highlyavailable-apps\pdb"
kubectl apply -f nginx/ -n dev
# Правим /etc/hosts прописываем ip worker node 192.168.0.151 nginx.local
curl nginx.local
StatusCode        : 200
```

Если в deployment стоят следующие настройки

```yaml
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
```

То при обновлении приложения на кокой-то небольшой момент будет работать только одна реплика.  

Сымитируем это поведение
```bash
kubectl scale deployment nginx --replicas=1 -n dev
```

Если в этот момент мы будем проводить работы на этом сервере. Т.е. запускаем kubectl drain то поды с этого сервера удаляются и запускаются где то в другом месте что приведет к downtime. Потому что реплика будет удалена.

kubectl cordon - помечает ноду как недоступную для scheduler. Новые поды не будут появляться
kubectl drain - делает сначала kubectl cordon а потом выселяет все поды на другие ноды.

```bash
# означает перемещение всех запущенных на узле подов на другие узлы. Это может быть полезным при плановом обслуживании узла, таком как обновление операционной системы или Kubernetes.
# --grace-period 60 Этот флаг определяет период ожидания в секундах перед тем, как Kubernetes начнет принудительное завершение (т.е., удаление) подов
# --delete-local-data: Этот флаг указывает Kubernetes удалить локальные данные (local data) подов. Локальные данные могут включать в себя временные файлы или другие данные, которые не были смонтированы в Persistent Volumes. Это помогает избежать потери данных при перемещении подов.
# --ignore-daemonsets: Этот флаг указывает Kubernetes не удалять поды, управляемые DaemonSets. DaemonSets обеспечивают запуск по крайней мере одного экземпляра пода на каждом узле, и игнорирование их позволяет сохранить один экземпляр работающего пода на каждом узле.
# --force: Этот флаг принудительно завершает (удаляет) поды без ожидания завершения периода ожидания, указанного в --grace-period. Используйте его с осторожностью, так как это может привести к потере данных, если поды не успели нормально завершить свою работу.
# Эта команда полезна при подготовке узла к обслуживанию или выключению. После выполнения kubectl drain, узел будет пуст, и его можно будет обслуживать или выключать
kubectl drain kub-worker-01 --grace-period 60 --delete-local-data --ignore-daemonsets --force
# Возвращение ноды в работу
kubectl uncordon kub-worker-01
```

Как избежать этих проблем:  
PodDisruptionBudget

pdb.yaml
```yaml
---
# Все приложения с label app: nginx должно быть доступно всегда хотя бы в одной реплике.
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: nginx
```
```bash
kubectl create -f pdb.yaml
kubectl get pdb -A
```

#  LimitRange и ResourceQuota

```bash
# Создаем namespace
kubectl create ns test
# Создаем в нем Limitrange и Resourcequota
kubectl apply -f limitrange.yaml -f resourcequota.yaml -n test
```
limitrange.yaml
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: limitrange
spec:
  limits:
  # Максимальные лимиты для контейнеров
  - type: Container
    max:
      cpu: 1
      memory: 1Gi
    # Это request
    min:
      cpu: 50m
      memory: 64Mi
    # Это default limit (на случай если мы не проставили)
    default:
      cpu: 100m
      memory: 128Mi
    # Это default request  
    defaultRequest:
      cpu: 100m
      memory: 128Mi
  # Максимальные лимиты для pod
  - type: Pod
    # Это настройка во сколько раз limit может превышать request
    maxLimitRequestRatio:
      cpu: 2
      memory: 2
  - type: PersistentVolumeClaim
    max:
      storage: 100Gi
    min:
      storage: 1Gi
```
resourcequota.yaml (лимиты на уровне namespace)
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resourcequota
spec:
  hard:
    limits.cpu: 5
    limits.memory: 5Gi
    requests.cpu: 5
    requests.memory: 5Gi
    requests.storage: 1024Gi
    pods: 10
    services: 10
    services.loadbalancers: 0
    services.nodeports: 0
    replicationcontrollers: 0
```

```bash
kubectl describe ns test
```

```bash
Resource Quotas
  Name:                   resourcequota
  Resource                Used  Hard
  --------                ---   ---
  limits.cpu              0     5
  limits.memory           0     5Gi
  pods                    0     10
  replicationcontrollers  0     0
  requests.cpu            0     5
  requests.memory         0     5Gi
  requests.storage        0     1Ti
  services                0     10
  services.loadbalancers  0     0
  services.nodeports      0     0

Resource Limits
 Type                   Resource  Min   Max    Default Request  Default Limit  Max Limit/Request Ratio
 ----                   --------  ---   ---    ---------------  -------------  -----------------------
 Container              cpu       50m   1      100m             100m           -
 Container              memory    64Mi  1Gi    128Mi            128Mi          -
 Pod                    memory    -     -      -                -              2
 Pod                    cpu       -     -      -                -              2
 PersistentVolumeClaim  storage   1Gi   100Gi  -                -              -
```
Проверяем
```bash
kubectl apply -f deployment.yaml -n test
kubectl describe ns test
```

Если квоты будут меньше чем выставлены в приложении то приложение не задеплоится

```bash
kubectl get rs -n test
# Ready 0
NAME              DESIRED   CURRENT   READY   AGE
nginx-bf545b765   2         2         0       3m44s
kubectl describe rs -n test nginx-bf545b765
kubectl delete ns test
```

# Priority Classes

```bash
# Чем больше цифра тем выше приоритет 
kubectl get pc
NAME                      VALUE        GLOBAL-DEFAULT   AGE
system-cluster-critical   2000000000   false            46d
system-node-critical      2000001000   false            46d

# Api server имеет наивысший приоритет
kubectl describe po -n kube-system kube-apiserver-kub-master-01 | grep Pri
Priority:             2000001000
Priority Class Name:  system-node-critical
# Calico тоже 2000001000
kubectl describe po -n kube-system calico-node-fm86f | grep Pri
```

Создаем Priority Class'ы и Namespace'ы для наших приложений

```bash
kubectl create -f pc-prod.yaml
kubectl create -f pc-develop.yaml

kubectl create ns production
kubectl create ns development
```

pc-develop.yaml
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: develop-priority
value: 900000000
```

pc-prod.yaml
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: production-priority
value: 1000000000
```

Деплоим наши приложения

```bash
kubectl create -f deployment-prod.yaml -n production
kubectl create -f deployment-develop.yaml -n development
```

deployment-prod.yaml
```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-prod
  template:
    metadata:
      labels:
        app: nginx-prod
    spec:
      priorityClassName: production-priority 
      containers:
        - image: nginx:1.13
          name: nginx-prod
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 200m
              memory: 200Mi
            limits:
              cpu: 200m
              memory: 200Mi
```

```bash
# Смотрим что сколько отожрало.
kubectl describe node kub-worker-01
Non-terminated Pods:          (14 in total)
  Namespace                   Name                                         CPU Requests  CPU Limits  Memory Requests  Memory Limits  Age
  ---------                   ----                                         ------------  ----------  ---------------  -------------  ---
  base                        access                                       0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  base                        base                                         0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  base                        test                                         0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  dev                         access                                       0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  dev                         nginx-d5944df46-9p24v                        50m (5%)      100m (10%)  100Mi (6%)       100Mi (6%)     117m
  dev                         test                                         0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  development                 nginx-develop-7f8497965b-xcldj               200m (20%)    200m (20%)  100Mi (6%)       100Mi (6%)     4m8s
  ingress-nginx               ingress-nginx-controller-765bb9f7c8-76w2k    100m (10%)    0 (0%)      90Mi (5%)        0 (0%)         44d
  kube-system                 calico-node-q2tkc                            250m (25%)    0 (0%)      0 (0%)           0 (0%)         44d
  kube-system                 kube-proxy-mxk78                             0 (0%)        0 (0%)      0 (0%)           0 (0%)         44d
  prod                        access                                       0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  prod                        test                                         0 (0%)        0 (0%)      0 (0%)           0 (0%)         23d
  production                  nginx-prod-544b9c9f85-rbcs6                  200m (20%)    200m (20%)  200Mi (12%)      200Mi (12%)    4m14s
  production                  nginx-prod-544b9c9f85-vx656                  200m (20%)    200m (20%)  200Mi (12%)      200Mi (12%)    4m14s
Allocated resources:
  (Total limits may be over 100 percent, i.e., overcommitted.)
  Resource           Requests     Limits
  --------           --------     ------
  cpu                1 (100%)     700m (70%)
  memory             690Mi (43%)  600Mi (37%)
  ephemeral-storage  0 (0%)       0 (0%)
  hugepages-1Gi      0 (0%)       0 (0%)
  hugepages-2Mi      0 (0%)       0 (0%)
```

Если у нас ноды будут отключаться и ресурсов будет не хватать то ноды с низким приоритетом не стартуют. Будут в pending.

У ingress nginx controller priority class = 0 Т.е. у него самый маленький приоритет.
```bash
kubectl describe po -n ingress-nginx ingress-nginx-controller-765bb9f7c8-76w2k
``` 

Всем критичным приложениям нужно выставлять Priority Class
