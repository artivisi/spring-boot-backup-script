# Development Instructions

## Project Overview

Ansible-based backup solution for Spring Boot applications. Handles database backup (PostgreSQL, MariaDB), file backup, and cloud storage sync (B2, GDrive, S3).

## Architecture

- One inventory per application (stored in `inventories/<app-name>/`)
- Single backup role handles all backup logic
- Playbooks orchestrate setup, backup, restore, and testing
- Secrets stored in Ansible Vault encrypted files

## Key Conventions

### Ansible

- Use Jinja2 templates (`.j2`) for all generated scripts
- Variables prefixed with `vault_` are secrets stored in vault.yml
- All tasks should be idempotent
- Use `become: true` only when root privileges are required

### Shell Scripts

- Use bash with `set -euo pipefail` for strict error handling
- Log to `/var/log/{{ app_name }}/backup.log`
- Exit with non-zero on any failure
- No fallback/default values - fail explicitly with error message

### File Paths on Target Server

```
/opt/{{ app_name }}/
├── scripts/
│   ├── backup.sh
│   ├── restore.sh
│   ├── report.sh
│   ├── cloud-sync.sh
│   ├── upload-b2.sh
│   ├── upload-gdrive.sh
│   └── upload-s3.sh
├── backup/              # local backup storage
├── .backup-key          # GPG private key
├── .pgpass              # PostgreSQL password file (if postgres)
├── .my.cnf              # MySQL/MariaDB credentials (if mariadb)
└── .config/rclone/rclone.conf  # rclone remote configuration

/var/log/{{ app_name }}/
├── backup.log
└── restore.log
```

## Testing Changes

```bash
# Lint playbooks
ansible-lint playbooks/*.yml

# Dry run setup
ansible-playbook playbooks/setup.yml -i inventories/<app>/ --check --diff

# Test backup connectivity without running actual backup
ansible-playbook playbooks/test.yml -i inventories/<app>/
```

## Multi-App Operations

Use `scripts/run-all.sh` to run any playbook across all configured inventories:

```bash
# Run backup on all apps
./scripts/run-all.sh backup --ask-vault-pass

# Generate report for all apps
./scripts/run-all.sh report --ask-vault-pass

# Deploy setup to all apps
./scripts/run-all.sh setup --ask-vault-pass
```

The script discovers inventories by looking for directories in `inventories/` containing a `hosts.yml` file.

## Adding New Cloud Provider

1. Create `roles/backup/tasks/cloud-<provider>.yml`
2. Create `roles/backup/templates/upload-<provider>.sh.j2`
3. Add variables to `roles/backup/defaults/main.yml`
4. Include task in `roles/backup/tasks/main.yml` with condition
5. Update cron task in `roles/backup/tasks/cron.yml`

## Adding New Database Type

1. Create `roles/backup/tasks/<dbtype>.yml` for credentials setup
2. Add dump command logic in `backup.sh.j2` template
3. Add restore command logic in `restore.sh.j2` template
4. Add variables to `roles/backup/defaults/main.yml`

## Error Handling

- Scripts must fail fast - no silent failures
- All errors must trigger Telegram notification
- Log detailed error messages before exiting
- Restore script must create safety backup before overwriting

## Commit Convention

Follow conventional commits:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation
- `refactor:` code restructuring
