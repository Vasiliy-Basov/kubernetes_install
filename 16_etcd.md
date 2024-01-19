# etcd
## etcd health check
https://github.com/ahrtr/etcd-issues/blob/master/docs/troubleshooting/sanity_check_and_collect_basic_info.md

```bash
# Посмотреть членов кластера
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem member list -w table
# Посмотреть статус всех endpoints
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem endpoint status -w table --cluster
# Health Check
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem endpoint health --cluster -w table
```

## etcd backup
```bash
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem snapshot save /var/lib/etcd/snapetcd2.db
```

## Recreate etcd node

```bash
# Remove node from cluster
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem member remove 72a11360bb345497
# stop service on broken node
systemctl stop etcd
# clear data on broken node
rm -rf /var/lib/etcd/
# Change env if needed "ETCD_INITIAL_CLUSTER_STATE=existing"
cat /etc/etcd.env
# Добавляем new member на одной из рабочих нод
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem member add etcd1 https://172.18.7.52:2380
# Можем проверить введя команду вручную
# Все адаптеры должны быть прописаны в DNS (У меня была следующая ошибка из за отсутствующей dns записи: "{"level":"warn","ts":"2024-01-18T10:32:00.798486Z","caller":"embed/config_logging.go:160","msg":"rejected connection","remote-addr":"172.18.7.61:34328","server-name":"","ip-addresses":["172.18.172.18.7.55","127.0.0.1"],"dns-names":["localhost","sztu-kubms-vt01","sztu-kubms-vt02","sztu-kubws-vt01","lb-apiserver.kubernetes.local","etcd.kube-system.svc.cluster.local","etcd.kube-system.s","etcd"],"error":"tls: \"172.18.7.61\" does not match any of DNSNames [\"localhost\" \"sztu-kubms-vt01\" \"sztu-kubms-vt02\" \"sztu-kubws-vt01\" \"lb-apiserver.kubernetes.local\" \"etcd.kube-sal\" \"etcd.kube-system.svc\" \"etcd.kube-system\" \"etcd\"] (lookup etcd on 172.18.5.207:53: dial udp 172.18.5.207:53: operation was canceled)"}")
etcd --name etcd1 \
  --data-dir /var/lib/etcd \
  --listen-peer-urls https://172.18.7.52:2380 \
  --listen-client-urls https://172.18.7.52:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://172.18.7.52:2379 \
  --initial-cluster-token k8s_etcd \
  --initial-advertise-peer-urls https://172.18.7.52:2380 \
  --initial-cluster etcd1=https://172.18.7.52:2380,etcd2=https://172.18.7.53:2380,etcd3=https://172.18.7.55:2380 \
  --client-cert-auth \
  --trusted-ca-file=/etc/ssl/etcd/ssl/ca.pem \
  --cert-file=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt01.pem \
  --key-file=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt01-key.pem \
  --peer-client-cert-auth \
  --peer-trusted-ca-file=/etc/ssl/etcd/ssl/ca.pem \
  --peer-cert-file=/etc/ssl/etcd/ssl/member-sztu-kubms-vt01.pem \
  --peer-key-file=/etc/ssl/etcd/ssl/member-sztu-kubms-vt01-key.pem \
  --initial-cluster-state existing
# Или просто запускаем службу
systemctl start etcd
# Проверяем что все заработало
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem endpoint health --cluster -w table
etcdctl --cacert=/etc/ssl/etcd/ssl/ca.pem  --cert=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02.pem  --key=/etc/ssl/etcd/ssl/admin-sztu-kubms-vt02-key.pem endpoint status -w table --cluster
```