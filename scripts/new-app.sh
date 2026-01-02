#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <app-name>"
    echo ""
    echo "Creates a new inventory for a Spring Boot application backup."
    echo ""
    echo "Example:"
    echo "  $0 myapp"
    exit 1
}

if [[ $# -ne 1 ]]; then
    usage
fi

APP_NAME="$1"
INVENTORY_DIR="${PROJECT_DIR}/inventories/${APP_NAME}"

if [[ -d "$INVENTORY_DIR" ]]; then
    echo "ERROR: Inventory already exists: ${INVENTORY_DIR}"
    exit 1
fi

echo "Creating inventory for: ${APP_NAME}"

# Create directory structure
mkdir -p "${INVENTORY_DIR}/group_vars"

# Create hosts.yml
cat > "${INVENTORY_DIR}/hosts.yml" << 'EOF'
all:
  hosts:
    prod:
      ansible_host: "{{ vault_server_ip }}"
      ansible_user: "{{ vault_server_user }}"
      ansible_python_interpreter: /usr/bin/python3
EOF

# Create all.yml
cat > "${INVENTORY_DIR}/group_vars/all.yml" << EOF
# Application identity
app_name: ${APP_NAME}
app_user: "{{ vault_app_user }}"
app_base_path: /opt/${APP_NAME}

# Database configuration
db_type: postgres  # postgres | mariadb
db_name: "{{ vault_db_name }}"
db_user: "{{ vault_db_user }}"
db_host: localhost
db_port: 5432  # 5432 for postgres, 3306 for mariadb

# Backup scope
backup_documents: true
backup_documents_path: "{{ app_base_path }}/documents"
backup_jar: false
backup_jar_path: "{{ app_base_path }}/app.jar"
backup_nginx: true
backup_nginx_path: /etc/nginx/sites-available/${APP_NAME}
backup_systemd: true
backup_systemd_path: /etc/systemd/system/${APP_NAME}.service

# Local retention
local_backup_path: "{{ app_base_path }}/backup"
local_retention_count: 7

# Cloud - Backblaze B2
cloud_b2_enabled: false
cloud_b2_bucket: "{{ vault_b2_bucket }}"
cloud_b2_path: "{{ vault_b2_path }}"
cloud_b2_retention_weeks: 4

# Cloud - Google Drive
cloud_gdrive_enabled: false
cloud_gdrive_folder: "{{ vault_gdrive_folder }}"
cloud_gdrive_retention_months: 12

# Cloud - AWS S3
cloud_s3_enabled: false
cloud_s3_bucket: "{{ vault_s3_bucket }}"
cloud_s3_prefix: ${APP_NAME}
cloud_s3_region: ap-southeast-1
cloud_s3_retention_days: 30

# Cron schedule
backup_cron_hour: 2
backup_cron_minute: 0
cloud_sync_cron_hour: 3
cloud_sync_cron_minute: 0

# Notifications
notification_telegram_enabled: true
EOF

# Create vault.yml.example
cat > "${INVENTORY_DIR}/group_vars/vault.yml.example" << 'EOF'
# Copy this file to vault.yml and encrypt with ansible-vault
# cp vault.yml.example vault.yml
# ansible-vault encrypt vault.yml

# Server connection
vault_server_ip: ""
vault_server_user: ""

# Application
vault_app_user: ""

# Database
vault_db_name: ""
vault_db_user: ""
vault_db_password: ""

# GPG key for backup encryption
# Generate with: openssl rand -base64 32
vault_gpg_key: ""

# Backblaze B2 (if cloud_b2_enabled)
vault_b2_bucket: ""
vault_b2_path: ""
vault_b2_account_id: ""
vault_b2_app_key: ""

# Google Drive (if cloud_gdrive_enabled)
# Run: rclone config (choose Google Drive)
# Then copy token from ~/.config/rclone/rclone.conf
vault_gdrive_folder: ""
vault_gdrive_token: ''

# AWS S3 (if cloud_s3_enabled)
vault_s3_bucket: ""
vault_s3_access_key: ""
vault_s3_secret_key: ""

# Telegram notifications
vault_telegram_bot_token: ""
vault_telegram_chat_id: ""
EOF

echo ""
echo "Inventory created: ${INVENTORY_DIR}"
echo ""
echo "Next steps:"
echo "1. Create and configure vault file:"
echo "   cp ${INVENTORY_DIR}/group_vars/vault.yml.example ${INVENTORY_DIR}/group_vars/vault.yml"
echo "   # Edit vault.yml with your values"
echo "   ansible-vault encrypt ${INVENTORY_DIR}/group_vars/vault.yml"
echo ""
echo "2. Edit ${INVENTORY_DIR}/group_vars/all.yml if needed (enable cloud providers, adjust retention)"
echo ""
echo "3. Deploy backup system:"
echo "   ansible-playbook playbooks/setup.yml -i inventories/${APP_NAME}/ --ask-vault-pass"
