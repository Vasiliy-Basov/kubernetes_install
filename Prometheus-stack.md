# Install Prometheus Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm search repo prometheus-community
helm pull prometheus-community/kube-prometheus-stack --untar
```

```bash
docker pull quay.io/prometheus/alertmanager:v0.27.0
docker tag quay.io/prometheus/alertmanager:v0.27.0 registry.local/prometheus/alertmanager:v0.27.0
docker push registry.local/prometheus/alertmanager:v0.27.0
```