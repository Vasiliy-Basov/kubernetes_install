# Registry install
## Install ping
```bash
sudo apt install iputils-ping
```
## Install docker
```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce
sudo systemctl status docker
# Executing the Docker Command Without Sudo (Optional) Добавляем пользователя под которым мы залогинены в группу docker
sudo usermod -aG docker ${USER}
su - ${USER}
groups
# или просто любого пользователя
sudo usermod -aG docker username
```

## Install Docker Compose
```bash
sudo curl -L "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

## Install Docker Registry
```bash
mkdir /mnt/registry
cd /mnt/registry
# Каталог для хранения образов
mkdir data
# Создаем Docker compose file
nano docker-compose.yml
```

```yaml
version: '3'

services:
  registry:
    restart: always
    image: registry:2.8.3
    ports:
    - "5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /data
    volumes:
      - /mnt/registry/data:/data
```

Утилита docker ожидает, что registry работает по защищенному соединению HTTPS. Можно разрешить подключение по незащищенному протоколу, для в конфигурационный файл демона docker нужно добавить следующую строку:

```bash
sudo nano /etc/docker/daemon.json
```
Настраиваем сети и бриджы так чтобы они не конфликтовали с нашими сетями.
```json
{
  "insecure-registries": ["172.18.7.76:5000"],
  "bip": "173.40.1.1/16",
  "fixed-cidr": "173.40.1.1/24",
  "default-address-pools": [
    {
      "base": "173.30.0.0/16",
      "size": 24
    },
    {
      "base": "173.31.0.0/16",
      "size": 24
    }
  ]
}
```

После чего перезапустить демон docker.
```bash
sudo systemctl restart docker
```

## Starting Docker Registry as Service
```bash
docker compose up -d
```