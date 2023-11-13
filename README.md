# Kubernetes Install

Install Ubuntu Server Minimazed - Выбираем при инсталляции Ubuntu Server

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
Содаем каталоги kubespray-venv для виртуального окружения и kubespray для проекта
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

# настройки сети (dns)
sudo cat /etc/resolv.conf

```