# Gitlab Install

## Change Ingress Options

add --set tcp.22="gitlab/mygitlab-gitlab-shell:22"  

https://kubernetes.github.io/ingress-nginx/deploy/
```bash
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.loadBalancerIP=172.18.7.70 --set controller.metrics.enabled=true --set tcp.22="gitlab/mygitlab-gitlab-shell:22"
```

## Set reclaim Policy to Storage Class
Set reclaimPolicy to Retain on Storage Class

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ssd-local
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: csi.vsphere.vmware.com
allowVolumeExpansion: true # Optional: only applicable to vSphere 7.0U1 and above
# При использовании Retain, ресурсы хранилища, связанные с PVC, не удаляются при удалении PVC
# В этом случае, если PVC удаляется, PV остается неизменным, и администратор кластера должен вручную принимать решение о том, что делать с PV.
reclaimPolicy: Retain
parameters:
  datastoreurl: "ds:///vmfs/volumes/12312avsihgbliou3ub2i3r9238hbr/"
  storagepolicyname: "Kuber-VMFS"
  csi.storage.k8s.io/fstype: ext4
```

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm search repo gitlab
helm pull gitlab/gitlab --untar
helm upgrade --install gitlab gitlab/gitlab --timeout 600s \
  --set global.hosts.domain=gitlab.local \
  --set global.hosts.externalIP=172.18.7.70 \
  --set global.edition=ce \
  --set gitlab-runner.runners.privileged=true \
  --set global.kas.enabled=true \
  --set global.ingress.class=nginx \
  --set nginx-ingress.enabled=false \
  --set certmanager.install=false \
  --set global.ingress.configureCertmanager=false \
  --create-namespace \
  -n gitlab

# или
helm upgrade --install gitlab gitlab/gitlab --timeout 600s --create-namespace -n gitlab -f /home/master/projects/kubernetes_install/gitlab/values_changed.yaml
```