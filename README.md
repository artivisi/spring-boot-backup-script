# Spring Boot Backup Script

Ansible-based backup solution for Spring Boot applications. Supports PostgreSQL and MariaDB/MySQL databases with cloud storage integration (Backblaze B2, Google Drive, AWS S3).

## Features

- **Database backup**: PostgreSQL and MariaDB/MySQL via `pg_dump` / `mysqldump`
- **File backup**: Application documents/uploads directory
- **Optional config backup**: JAR file, Nginx config, systemd service
- **Cloud storage**: Backblaze B2, Google Drive, AWS S3 with GPG encryption
- **Local retention**: Configurable rotation of local backups
- **Restore**: Full restoration with checksum verification
- **Notifications**: Telegram alerts for success/failure
- **Per-app isolation**: Each app has its own inventory, credentials, and encryption key

## Requirements

- Ansible 2.14+
- Target server: Debian/Ubuntu with systemd
- rclone (installed automatically by playbook)
- gpg (for backup encryption)

## Directory Structure

```
spring-boot-backup-script/
├── inventories/
│   └── <app-name>/
│       ├── hosts.yml
│       └── group_vars/
│           ├── all.yml       # app configuration
│           └── vault.yml     # secrets (ansible-vault encrypted)
├── playbooks/
│   ├── setup.yml             # install backup system on server
│   ├── backup.yml            # trigger immediate backup
│   ├── restore.yml           # restore from backup file
│   ├── test.yml              # verify backup and cloud connectivity
│   └── generate-gpg-key.yml  # generate GPG key for new app
├── roles/
│   └── backup/
└── scripts/
    └── new-app.sh            # scaffold new app inventory
```

## Quick Start

### 1. Create inventory for your app

```bash
./scripts/new-app.sh myapp
```

This creates `inventories/myapp/` with template configuration files.

### 2. Configure the app

Edit `inventories/myapp/hosts.yml`:
```yaml
all:
  hosts:
    prod:
      ansible_host: 192.168.1.100
      ansible_user: deploy
```

Edit `inventories/myapp/group_vars/all.yml`:
```yaml
app_name: myapp
app_user: myapp
app_base_path: /opt/myapp

db_type: postgres  # or mariadb
db_name: myappdb
db_user: myapp
db_host: localhost
db_port: 5432

backup_documents: true
backup_documents_path: "{{ app_base_path }}/documents"

cloud_b2_enabled: true
cloud_b2_bucket: myapp-backups
# ... see all.yml for full options
```

### 3. Configure secrets

Generate GPG key:
```bash
ansible-playbook playbooks/generate-gpg-key.yml -e app_name=myapp
```

Create vault file:
```bash
ansible-vault create inventories/myapp/group_vars/vault.yml
```

Add secrets:
```yaml
vault_db_password: "your-db-password"
vault_gpg_key: |
  -----BEGIN PGP PRIVATE KEY BLOCK-----
  ... (output from generate-gpg-key.yml)
  -----END PGP PRIVATE KEY BLOCK-----

vault_b2_account_id: "your-b2-account-id"
vault_b2_app_key: "your-b2-app-key"

vault_telegram_bot_token: "123456:ABC..."
vault_telegram_chat_id: "-100123456789"
```

### 4. Deploy backup system

```bash
ansible-playbook playbooks/setup.yml -i inventories/myapp/ --ask-vault-pass
```

### 5. Test backup

```bash
ansible-playbook playbooks/test.yml -i inventories/myapp/ --ask-vault-pass
```

## Usage

### Run immediate backup

```bash
ansible-playbook playbooks/backup.yml -i inventories/myapp/ --ask-vault-pass
```

### Restore from backup

```bash
ansible-playbook playbooks/restore.yml -i inventories/myapp/ --ask-vault-pass \
  -e backup_file=/opt/myapp/backup/myapp_20260102_020000.tar.gz
```

### Restore from cloud backup

Download the encrypted backup from cloud storage first, then:

```bash
# Decrypt the backup
gpg --decrypt backup_encrypted.tar.gz.gpg > backup.tar.gz

# Run restore
ansible-playbook playbooks/restore.yml -i inventories/myapp/ --ask-vault-pass \
  -e backup_file=/path/to/backup.tar.gz
```

## Backup Schedule

Default cron schedule (configurable per-app):
- Local backup: Daily at 02:00
- Cloud sync: Daily at 03:00

## Backup Archive Contents

```
myapp_20260102_020000.tar.gz
├── manifest.json          # metadata and checksums
├── database.sql           # database dump
├── documents/             # uploaded files (if enabled)
├── app.jar                # application binary (if enabled)
├── nginx.conf             # nginx config (if enabled)
└── systemd.service        # systemd unit (if enabled)
```

## Configuration Reference

See `roles/backup/defaults/main.yml` for all available configuration options.

## Secrets Management

- Secrets are stored in `vault.yml` files, encrypted with Ansible Vault
- GPG encryption key is stored in vault and deployed to server
- Store Ansible Vault password in Bitwarden or similar password manager
- Each app has isolated credentials and encryption keys

## Notifications

Telegram notifications include:
- Backup success/failure status
- Backup size and duration
- Cloud upload status for each enabled provider
- Error details on failure

## License

Apache License 2.0
