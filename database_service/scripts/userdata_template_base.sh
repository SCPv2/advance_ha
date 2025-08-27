#!/bin/bash
# Samsung Cloud Platform v2 (OpenStack) - Compact UserData Base
# 45KB limit optimized for OpenStack cloud-init

set -euo pipefail
SERVER_TYPE="${SERVER_TYPE}"
LOGFILE="/var/log/userdata_${SERVER_TYPE}.log"
exec 1> >(tee -a $LOGFILE) 2>&1

echo "=== ${SERVER_TYPE^} Server Init: $(date) ==="

# Module 0: Local DNS Resolution
local_dns_setup() {
    echo "[0/5] Local DNS Resolution setup..."
    
    # Define domain mappings
    PRIVATE_DOMAIN="${private_domain_name}"
    WEB_IP="${web_ip}"
    APP_IP="${app_ip}"
    DB_IP="${db_ip}"
    
    # Create temporary hosts entries
    cat >> /etc/hosts << EOF

# === SCPv2 Temporary DNS Mappings ===
${WEB_IP} www.${PRIVATE_DOMAIN}
${APP_IP} app.${PRIVATE_DOMAIN}
${DB_IP} db.${PRIVATE_DOMAIN}
# === End SCPv2 Mappings ===
EOF
    
    echo "✅ Local DNS mappings added to /etc/hosts"
    echo "   www.${PRIVATE_DOMAIN} -> ${WEB_IP}"
    echo "   app.${PRIVATE_DOMAIN} -> ${APP_IP}"
    echo "   db.${PRIVATE_DOMAIN} -> ${DB_IP}"
}

# Module 1: System Update (Compact)
sys_update() {
    echo "[1/5] System update..."
    until curl -s --connect-timeout 5 http://www.google.com >/dev/null 2>&1; do sleep 10; done
    for i in {1..3}; do dnf clean all && dnf install -y epel-release && break; sleep 30; done
    dnf -y update upgrade || true
    dnf install -y wget curl git jq htop net-tools chrony || true
    
    # Samsung SDS Cloud NTP configuration
    echo "server 198.19.0.54 iburst" >> /etc/chrony.conf
    systemctl enable chronyd && systemctl restart chronyd
    echo "✅ System updated with NTP"
}

# Module 2: Repository Clone
repo_clone() {
    echo "[2/5] Repository clone..."
    id rocky || (useradd -m rocky && usermod -aG wheel rocky)
    cd /home/rocky
    [ ! -d ceweb ] && sudo -u rocky git clone https://github.com/SCPv2/ceweb.git || true
    echo "✅ Repository ready"
}

# Module 3: Config Injection (Template substitution)
config_inject() {
    echo "[3/5] Config injection..."
    cat > /home/rocky/master_config.json << 'CONFIG_EOF'
${MASTER_CONFIG_JSON_CONTENT}
CONFIG_EOF
    chown rocky:rocky /home/rocky/master_config.json
    chmod 644 /home/rocky/master_config.json
    sudo -u rocky mkdir -p /home/rocky/ceweb/web-server
    cp /home/rocky/master_config.json /home/rocky/ceweb/web-server/
    chown rocky:rocky /home/rocky/ceweb/web-server/master_config.json
    jq . /home/rocky/master_config.json >/dev/null || exit 1
    echo "✅ Config injected"
}

# Module 3 & 5: Application Install and Verification (Server-specific - will be injected)
${APPLICATION_INSTALL_MODULE}

# Module 6: Local DNS Cleanup
local_dns_cleanup() {
    echo "[6/6] Local DNS Resolution cleanup..."
    
    # Remove SCPv2 temporary DNS mappings from /etc/hosts
    sudo sed -i '/# === SCPv2 Temporary DNS Mappings ===/,/# === End SCPv2 Mappings ===/d' /etc/hosts
    
    echo "✅ Local DNS mappings cleaned up from /etc/hosts"
}

# Main execution
main() {
    local_dns_setup
    sys_update
    repo_clone
    config_inject
    app_install
    verify_install
    local_dns_cleanup
    echo "${SERVER_TYPE^} ready: $(date)" > /home/rocky/${SERVER_TYPE^}_Ready.log
    echo "=== ${SERVER_TYPE^} Init Complete: $(date) ==="
}

main