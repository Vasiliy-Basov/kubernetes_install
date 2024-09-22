# Kubernetes Full Process

![](/pics/kub-process.png)

Все общение в кластере происходит через api server

## Устройство kubernetes
![](/pics/kub-schema.png)

- `kubectl` - утилита для обращения к api kubernetes сервера
- `API Server / Auth` - то куда обращается kubectl на master node c авторизацией
- `Scheduler` - процесс master node который планирует размещение подов (дает задание ноде поднять pod-ы)
- `kubelet` - сервис на ноде который выполняет инструкции от Scheduler и поднимает поды уже на конкретных нодах
- `Controller manager` - Контроллеры которые управляют жизненным циклом всего кластера, следит чтобы в кластере соблюдалась наша текущая конфигурация.
- `etcd` - локальная база данных которая хранит всю информацию.

## Scheduler

1. Он смотрит на api server и ищет там поды на которых не стоит spec.nodeName=""
2. Далее он отфильтровывает те ноды которые не подходят для подов. 
Filter Nodes
- nodeSelector
- tolerations
- affinity
- status   

3. Далее он расставляет все ноды в порядке приоритета, нода которая наберет больше всего баллов это та нода на которой запустится pod.  
Score nodes
- preferred
- affinity
- taints
- resources

![](/pics/scheduler.png)

## Controller manager

Контроллеры которые управляют жизненным циклом всего кластера
- Создание новых pod
- Управляют ReplicaSet
- Управляют CronJob
- Управляют Horizontal Pod Autoscaler


![](/pics/controllermanager.png)

## Operators - собственные контроллеры

Задача - смотреть в api server за своими объектами и в ответ на появление объектов что то создавать и т.д.

Эти объекты custom-ные: CRD

## Версии API

Строка apiVersion в конфигурации:  
![](/pics/apiversion.png)
