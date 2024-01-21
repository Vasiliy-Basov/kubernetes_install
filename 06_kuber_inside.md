# Kubernetes Full Process

![](/pics/kub-process.png)

Все общение в кластере происходит через api server

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

