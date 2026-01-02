# Implementation Plan

## Phase 1: Project Structure

Create base directory structure and configuration:

```
spring-boot-backup-script/
├── ansible.cfg
├── inventories/
│   └── aplikasi-akunting/
│       ├── hosts.yml
│       └── group_vars/
│           ├── all.yml
│           └── vault.yml.example
├── playbooks/
├── roles/
│   └── backup/
│       ├── defaults/
│       ├── tasks/
│       └── templates/
└── scripts/
```

Files to create:
- `ansible.cfg` - Ansible configuration with inventory path, roles path
- `inventories/aplikasi-akunting/hosts.yml` - server definition
- `inventories/aplikasi-akunting/group_vars/all.yml` - app configuration
- `inventories/aplikasi-akunting/group_vars/vault.yml.example` - secrets template

## Phase 2: Backup Role - Defaults and Core Tasks

### roles/backup/defaults/main.yml

Define all configurable variables with sensible defaults:
- App identity (name, user, base path)
- Database settings (type, host, port, name, user)
- Backup scope flags (documents, jar, nginx, systemd)
- Local retention settings
- Cloud provider toggles and settings (B2, GDrive, S3)
- Cron schedule settings
- Notification settings

### roles/backup/tasks/main.yml

Orchestrate all tasks:
1. Include directories.yml
2. Include scripts.yml
3. Include postgres.yml (when db_type == 'postgres')
4. Include mariadb.yml (when db_type == 'mariadb')
5. Include cloud-b2.yml (when cloud_b2_enabled)
6. Include cloud-gdrive.yml (when cloud_gdrive_enabled)
7. Include cloud-s3.yml (when cloud_s3_enabled)
8. Include cron.yml
9. Include verify.yml

### roles/backup/tasks/directories.yml

- Create /opt/{{ app_name }}/scripts
- Create /opt/{{ app_name }}/backup
- Create /var/log/{{ app_name }}
- Set ownership to {{ app_user }}

### roles/backup/tasks/scripts.yml

- Deploy backup.sh from template
- Deploy restore.sh from template
- Deploy backup.conf from template
- Deploy GPG key from vault
- Set permissions (700 for scripts, 600 for key)

## Phase 3: Database Tasks

### roles/backup/tasks/postgres.yml

- Create .pgpass file with credentials
- Set permissions 600

### roles/backup/tasks/mariadb.yml

- Create .my.cnf file with credentials
- Set permissions 600

## Phase 4: Backup Script Template

### roles/backup/templates/backup.sh.j2

Main backup script logic:

```
1. Set variables from backup.conf
2. Create timestamp and backup filename
3. Create temp directory for staging

4. Database backup:
   - If postgres: pg_dump to database.sql
   - If mariadb: mysqldump to database.sql
   - Calculate checksum

5. Document backup (if enabled):
   - tar documents directory
   - Calculate checksum

6. Optional backups:
   - Copy JAR file (if backup_jar)
   - Copy nginx config (if backup_nginx)
   - Copy systemd service (if backup_systemd)

7. Create manifest.json with:
   - Timestamp
   - App name
   - Checksums for each component
   - Backup scope flags

8. Create final tar.gz archive

9. Local rotation:
   - List backups sorted by date
   - Remove oldest if count > retention

10. Trigger cloud uploads:
    - Run upload-b2.sh (if enabled)
    - Run upload-gdrive.sh (if enabled)
    - Run upload-s3.sh (if enabled)

11. Send notification with results

12. Cleanup temp directory
```

## Phase 5: Restore Script Template

### roles/backup/templates/restore.sh.j2

Restore script logic:

```
1. Parse arguments (backup file path)
2. Validate backup file exists
3. Stop application service

4. Extract archive to temp directory
5. Validate manifest.json exists
6. Verify checksums match

7. Database restore:
   - Terminate existing connections
   - Drop and recreate database
   - Restore from database.sql

8. Document restore (if present):
   - Create safety backup of current documents
   - Extract documents to target path

9. Config restore (if present in archive):
   - Restore JAR file
   - Restore nginx config, reload nginx
   - Restore systemd service, daemon-reload

10. Start application service
11. Cleanup temp directory
12. Log completion
```

## Phase 6: Cloud Upload Scripts

### roles/backup/templates/upload-b2.sh.j2

- Source backup.conf
- Find latest backup file
- Encrypt with GPG
- Upload via rclone to B2
- Apply retention policy (delete old backups)
- Log result
- Cleanup encrypted temp file

### roles/backup/templates/upload-gdrive.sh.j2

- Same structure as B2
- Upload to Google Drive folder
- Monthly retention policy

### roles/backup/templates/upload-s3.sh.j2

- Same structure as B2
- Upload to S3 bucket with prefix
- Configurable retention in days

### roles/backup/tasks/cloud-b2.yml

- Install rclone (if not present)
- Deploy rclone.conf with B2 credentials
- Deploy upload-b2.sh script
- Test B2 connectivity

### roles/backup/tasks/cloud-gdrive.yml

- Deploy rclone.conf with GDrive token
- Deploy upload-gdrive.sh script
- Test GDrive connectivity

### roles/backup/tasks/cloud-s3.yml

- Deploy rclone.conf with S3 credentials
- Deploy upload-s3.sh script
- Test S3 connectivity

## Phase 7: Cron and Notifications

### roles/backup/tasks/cron.yml

- Create cron job for daily backup
- Create cron job for cloud sync (runs after backup)

### roles/backup/templates/backup.conf.j2

Configuration file sourced by scripts:
- App name and paths
- Database connection info
- Retention settings
- Cloud provider flags
- Notification settings

## Phase 8: Playbooks

### playbooks/setup.yml

```yaml
- hosts: all
  become: true
  roles:
    - backup
```

### playbooks/backup.yml

```yaml
- hosts: all
  become: true
  tasks:
    - name: Run backup
      command: /opt/{{ app_name }}/scripts/backup.sh
      register: backup_result
    - name: Show result
      debug:
        var: backup_result.stdout_lines
```

### playbooks/restore.yml

```yaml
- hosts: all
  become: true
  vars_prompt:
    - name: backup_file
      prompt: "Path to backup file"
      private: false
  tasks:
    - name: Run restore
      command: /opt/{{ app_name }}/scripts/restore.sh {{ backup_file }}
```

### playbooks/test.yml

```yaml
- hosts: all
  become: true
  tasks:
    - name: Test database connection
    - name: Test backup script (dry run)
    - name: Test B2 connectivity (if enabled)
    - name: Test GDrive connectivity (if enabled)
    - name: Test S3 connectivity (if enabled)
    - name: Test Telegram notification
```

### playbooks/generate-gpg-key.yml

```yaml
- hosts: localhost
  tasks:
    - name: Generate GPG key pair
      command: gpg --gen-key --batch
    - name: Export private key
    - name: Display key for vault storage
```

## Phase 9: Helper Scripts

### scripts/new-app.sh

Shell script to scaffold new app inventory:
- Create inventories/<app>/
- Create hosts.yml template
- Create group_vars/all.yml with placeholders
- Create group_vars/vault.yml.example
- Print next steps

## Implementation Order

1. Phase 1: Project structure, ansible.cfg, aplikasi-akunting inventory
2. Phase 2: Role defaults and core task orchestration
3. Phase 3: Database credential tasks (postgres, mariadb)
4. Phase 4: backup.sh.j2 template
5. Phase 5: restore.sh.j2 template
6. Phase 6: Cloud upload scripts and tasks
7. Phase 7: Cron tasks and backup.conf
8. Phase 8: All playbooks
9. Phase 9: new-app.sh helper script
