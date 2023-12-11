# Gitlab Install

## Change Ingress Options

add --set tcp.22="gitlab/mygitlab-gitlab-shell:22"
https://kubernetes.github.io/ingress-nginx/deploy/
```bash
helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.loadBalancerIP=172.18.7.70 --set controller.metrics.enabled=true --set tcp.22="gitlab/mygitlab-gitlab-shell:22"
```

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm search repo gitlab
helm pull gitlab/gitlab --untar
helm upgrade --install gitlab gitlab/gitlab --timeout 600s \
  --set global.hosts.domain=gitlab.basov.world \
  --set global.hosts.externalIP=35.192.162.100 \
  --set global.edition=ce \
  --set gitlab-runner.runners.privileged=true \
  --set global.kas.enabled=true \
  --set global.ingress.class=nginx \
  --set nginx-ingress.enabled=false \
  --set certmanager.install=false \
  --set global.ingress.configureCertmanager=false \
  --create-namespace \
  -n gitlab

