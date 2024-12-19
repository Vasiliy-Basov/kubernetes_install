#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root"
   exit 1
fi

# Script for automatic Kubernetes certificate renewal
# This should be placed on both master nodes

# Log file setup
LOG_FILE="/var/log/k8s-cert-renewal.log"
CERT_BACKUP_DIR="/root/k8s-cert-backups/$(date +%Y%m%d)"
DATE_ISO=$(date --iso)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_certificates() {
    local needs_renewal=1
    local expired_certs=()

    # Suppress the kubelet DNS warning
    exec 2>/dev/null

    # Process each certificate
    while read -r line; do
        # Skip CA certificates
        if echo "$line" | grep -q "CERTIFICATE AUTHORITY"; then
            continue
        fi

        # Extract certificate details
        cert_name=$(echo "$line" | awk '{print $1}')
        expiry_date=$(echo "$line" | awk '{print $2, $3, $4}')

        # Calculate days until expiry
        expiry_timestamp=$(date -d "$expiry_date" +%s)
        current_timestamp=$(date +%s)
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

        # Check if certificate needs renewal
        if [ "$days_until_expiry" -lt 30 ]; then
            expired_certs+=("$cert_name (expires in $days_until_expiry days)")
            needs_renewal=0
        fi
    done < <(kubeadm certs check-expiration | grep UTC)

    # Log details if certificates need renewal
    if [ "$needs_renewal" -eq 0 ]; then
        log "Certificates that need renewal:"
        for cert in "${expired_certs[@]}"; do
            log "- $cert"
        done
    fi

    return $needs_renewal
}

backup_certificates() {
    log "Creating backup directory: $CERT_BACKUP_DIR"
    mkdir -p "$CERT_BACKUP_DIR"

    log "Backing up certificates and kubeconfig files"
    cp -R /etc/kubernetes/ssl "$CERT_BACKUP_DIR/ssl.backup" 2>/dev/null || true
    cp /etc/kubernetes/admin.conf "$CERT_BACKUP_DIR/admin.conf.backup" 2>/dev/null || true
    cp /etc/kubernetes/controller-manager.conf "$CERT_BACKUP_DIR/controller-manager.conf.backup" 2>/dev/null || true
    cp /etc/kubernetes/kubelet.conf "$CERT_BACKUP_DIR/kubelet.conf.backup" 2>/dev/null || true
    cp /etc/kubernetes/scheduler.conf "$CERT_BACKUP_DIR/scheduler.conf.backup" 2>/dev/null || true

    # Backup kube config with date in filename
    log "Backing up kube config with date"
    cp /root/.kube/config "/root/.kube/.old-${DATE_ISO}-config" 2>/dev/null || true
}

restart_control_plane() {
    log "Restarting Kubernetes control plane pods"

    # Массив компонентов и их пути к манифестам
    declare -A component_paths=(
        ["kube-apiserver"]="/etc/kubernetes/manifests/kube-apiserver.yaml"
        ["kube-controller-manager"]="/etc/kubernetes/manifests/kube-controller-manager.yaml"
        ["kube-scheduler"]="/etc/kubernetes/manifests/kube-scheduler.yaml"
        ["kube-vip"]="/etc/kubernetes/manifests/kube-vip.yml"
    )

    for component in "${!component_paths[@]}"; do
        manifest_path="${component_paths[$component]}"

        log "Restarting $component"

        if [ -f "$manifest_path" ]; then
            # Создаем резервную копию
            backup_path="${manifest_path}.backup"
            cp "$manifest_path" "$backup_path"

            # Удаляем манифест
            rm "$manifest_path"

            log "Waiting for $component pod to be removed"
            sleep 40

            # Восстанавливаем манифест
            mv "$backup_path" "$manifest_path"

            log "$component pod restarted"
        else
            log "Manifest for $component not found"
        fi
    done

    # Финальная проверка кластера
    log "Performing final cluster health check"
    if ! kubectl get nodes &>/dev/null; then
        log "Error: Cluster is not responding after control plane restart"
        return 1
    fi

    log "Control plane restart completed successfully"
    return 0
}

renew_certificates() {
    log "Starting certificate renewal process"

    # Backup existing certificates
    backup_certificates

    # Renew certificates
    log "Renewing certificates"
    kubeadm certs renew all

    # Update kubeconfig
    log "Updating kubeconfig"
    cp /etc/kubernetes/admin.conf /root/.kube/config

    # Restart control plane pods
    if ! restart_control_plane; then
        log "Error during control plane restart"
        exit 1
    fi

    # Restart kubelet
    log "Restarting kubelet service"
    systemctl restart kubelet

    log "Certificate renewal completed successfully"
}


# Main execution
log "Starting certificate check"
if check_certificates; then
    log "Certificates need renewal"
    renew_certificates
else
    log "Certificates are still valid for more than 30 days"
fi
