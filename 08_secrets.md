# Secrets

Все секреты который создаются командой kubectl create secret generic становятся:  
type: Opaque  
Еще бывают секреты   
docker-registry  
tls  
Создаются автоматически при создании service account (внутри токены от sa)  
service account  

## Create a Secret using kubectl from-file:
```bash
# Название ключа будет названием файла а содержимое файла паролем
kubectl create secret generic mygreatsecret \
  --from-file=username.txt

# Так можем указать название ключа вместо key
kubectl create secret generic mygreatsecret \
  --from-file=key=username.txt

# Задаем напрямую из командной строки dbpass ключ, rootpassword значение
kubectl create secret generic mygreatsecret \
  --from-literal=dbpass=rootpassword

# или
kubectl create secret generic db-user-pass-from-literal \
  --from-literal=username=devuser \
  --from-literal=password='P!S?*r$zDsY'

# Сразу несколько секретов из одного файла, все пары будут созданы в одном секрете
kubectl create secret generic mygreatsecret \
  --from-env-file=file.env

echo -n 'admin' > ./username.txt
echo -n 'superpass12345&*' > ./password.txt

kubectl create secret generic db-user-pass-from-file \
  --from-file=./username.txt \
  --from-file=./password.txt
kubectl get secret db-user-pass-from-file -o yaml
```

## Decoding the Secret:

```bash
kubectl get secret db-user-pass-from-file -o jsonpath='{.data}'
```

```bash
kubectl get secret db-user-pass-from-literal -o jsonpath='{.data.password}' | base64 --decode
```

## Secrets from yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-stringdata
type: Opaque
# В этом поле значение закодировано в BASE64
data:
  username: YWRtaW51c2Vy
# Здесь значения не закодированы но закодируются при применении в kub
stringData:
  apiUrl: "https://my.api.com/api/v1"
  username: adminuser
  password: Rt2GG#(ERgf09
```

## Как использовать переменные в контейнере:

1. С помощью переменных
\nginx_learning\kubernetes\27_secrets\example-1\deploy-resume-2.yaml

```yaml
      containers:
      - name: resume-secret-test
        image: vasiliybasov/resume:1.0
        ports:
        - name: http
          containerPort: 80
        # Получаем переменные для контейнера из секрета secret-stringdata
        # Переменной SECRET_USERNAME мы присваиваем значение указанное для ключа username в секрете
        env:
          - name: SECRET_USERNAME
            # Откуда брать значение
            valueFrom:
              # Брать значение из секрета
              secretKeyRef:
                # Из какого секрета берем значение
                name: secret-stringdata
                # берем значение username из этого секрета и присваиваем переменной SECRET_USERNAME в контейнере
                key: username
          - name: SECRET_PASSWORD
            valueFrom:
              secretKeyRef:
                name: secret-stringdata
                key: password
```

2. С помощью монтирования файла
\nginx_learning\kubernetes\27_secrets\example-1\deploy-resume-1.yaml
```yaml
  # Шаблон на основе которого будут создаваться поды
  template:
    metadata:
      # Labels должны совпадать с теми которые указаны в блоке selector
      labels:
        app: http-server
    spec:
      containers:
      - name: resume-secret-test
        image: vasiliybasov/resume:1.0
        ports:
        - name: http
          containerPort: 80
        # Вместо переменных окружения env мы монтируем в файлы (в нашем случае файлы password и username) наши секреты внутрь нашего контейнера по пути /etc/secrets. Файлы будут называться как ключи в нашем секрете а значение этих файлов будут значения наших ключей.
        # На самом деле password и username будут там в качестве линков сами файлы находятся внутри каталога со временем создания.
        volumeMounts:
        - name: secrets
          # ! Если в каталоге /etc/secrets уже что то было внутри контейнера, то эти файлы будут срыты монтированием и пропадут, надо это учитывать. Нельзя монтировать секреты в уже существующие каталоги.
          mountPath: "/etc/secrets"
      volumes:
      - name: secrets
        secret:
          secretName: secret-data
          # права на файлы которые будут создаваться
          defaultMode: 0400
```

В etcd секреты хранятся в нешифрованном виде.

# Хранение секретов в сторонних провайдерах Hashicorp Vault

- Хранит все в зашифрованном виде
- Разграничение прав доступа
- Аудит
- Ротация секретов
- Режим высокой доступности, несколько экземпляров Vault которые работают с одним хранилищем. HA storage. Один master остальные ждут ы резерве.
- Vault нужно при запуске включить ключ расшифровки sealed Shamir. Мы должны ввести любые 3 части из 5 сгенерированные.
- Можно настроить чтобы ключи брались из Google Cloud kms. Когда vault запускается он идет в Google KMS берет от туда ключ и начинает работать

Как брать секреты из Vault:  
1) Напрямую но Vault работает медленно так как это криптография  
2) Можно копировать данные из Vault в секреты в kubernetes  
3) Налету исправлять deployment и доставлять секреты напрямую в контейнер с приложением

Практика: 

# Установка Hashicorp Vault

## Устанавливаем оператор Vault от BanzaiCloud

```
helm repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com
kubectl create namespace vault-infra
kubectl label namespace vault-infra name=vault-infra
helm upgrade --namespace vault-infra --install vault-operator banzaicloud-stable/vault-operator --wait
```

## Устанавливаем Vault
Создадим кастомный ресурс, который скажет оператору создать нам vault

kubernetes_install/vault/cr.yaml

Изменения
```yaml
  # Будет работать от этого аккаунта
  serviceAccount: vault

  ingress:
    # Specify Ingress object annotations here, if TLS is enabled (which is by default)
    # the operator will add NGINX, Traefik and HAProxy Ingress compatible annotations
    # to support TLS backends
    annotations: {}
    # Override the default Ingress specification here
    # This follows the same format as the standard Kubernetes Ingress
    # See: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.13/#ingressspec-v1beta1-extensions
    spec:
      ingressClassName: nginx
      rules:
        - host: vault.cluster.local
          http:
            paths:
            - pathType: Prefix
              path: /
              backend:
                service:
                  name: vault
                  port:
                    number: 8200


apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: vault-file
spec:
  # https://kubernetes.io/docs/concepts/storage/persistent-volumes/#class-1
  storageClassName: "local-storage-cockroach"
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```
