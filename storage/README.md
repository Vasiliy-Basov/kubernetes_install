# Storage commands

Поменять persistentVolumeReclaimPolicy на Retain для PV

```bash
kubectl patch pv pvc-fb40296b-e7a5-4318-8944-7c8c413c2111 -p '{"spec": {"persistentVolumeReclaimPolicy": "Retain"}}'
```