# ansible-kasm

Ansible role for deploying and managing [Kasm Workspaces](https://www.kasmweb.com). Supports all-in-one and distributed multi-server deployments across single or multiple zones.

## Requirements

- Ansible 2.10 or greater on the control node
- `community.docker` collection and `geerlingguy.docker` role — install with:
  ```bash
  ansible-galaxy install -r requirements.yml
  ```
- Target hosts: Debian 12+, Ubuntu 22.04+, or Rocky Linux 9/10
- Target hosts must have passwordless sudo configured for the Ansible SSH user
- `python3-docker` is installed automatically on target hosts during deploy

## Role structure

This directory is the role itself. When placed inside a wider repository, it lives at `ansible/roles/kasm/`. The playbook `deploy_and_configure_kasm.yml` should sit alongside your other playbooks.

## Quick start

1. Place the Kasm installer tarball (`kasm_release_*.tar.gz`) in `files/`
2. Configure your `inventory` file
3. Set per-host variables in `host_vars/`
4. Run the deploy:

```bash
ansible-playbook -i inventory deploy_and_configure_kasm.yml
```

## Usage

All operations go through a single playbook. The `kasm_action` variable controls what runs — it defaults to `deploy`.

| Action | Command |
|---|---|
| Deploy | `ansible-playbook -i inventory deploy_and_configure_kasm.yml` |
| Upgrade | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=upgrade` |
| Uninstall | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=uninstall` |
| Start | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=start` |
| Stop | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=stop` |
| Restart | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=restart` |
| Backup DB | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=backup` |
| Restore DB | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=restore -e kasm_restore_file=/path/to/backup.tar.gz` |
| Apply certs | `ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=certs` |

## Inventory

Each host declares which Kasm services it runs via `kasm_services` in `host_vars/`. Valid services are `db`, `web`, `agent`, `guac`, `proxy`.

### All-in-one (single host)

```ini
[zone1]
kasm1  ansible_host=192.168.1.10  ansible_user=ubuntu
```

```yaml
# host_vars/kasm1.yml
kasm_services:
  - db
  - web
  - agent
  - guac
kasm_zone: zone1
```

### Distributed (multi-server)

```ini
[zone1]
zone1_db_1     ansible_host=10.0.0.10  ansible_user=ubuntu
zone1_web_1    ansible_host=10.0.0.11  ansible_user=ubuntu
zone1_agent_1  ansible_host=10.0.0.12  ansible_user=ubuntu
zone1_agent_2  ansible_host=10.0.0.13  ansible_user=ubuntu
zone1_guac_1   ansible_host=10.0.0.14  ansible_user=ubuntu
```

```yaml
# host_vars/zone1_db_1.yml
kasm_services: [db]
kasm_zone: zone1

# host_vars/zone1_web_1.yml
kasm_services: [web]
kasm_zone: zone1

# host_vars/zone1_agent_1.yml
kasm_services: [agent]
kasm_zone: zone1
```

### Multiple zones

Add additional zone groups to inventory and list all zones in `group_vars/all/vars.yml`:

```yaml
zones:
  - zone1
  - zone2
```

## Credentials

Credentials are auto-generated on first deploy and written to `group_vars/all/vault.yml`. Encrypt this file before committing:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

To use a pre-existing set of credentials, populate `group_vars/all/vault.yml` before running the deploy.

## Variables

All variables and their defaults are documented in `defaults/main.yml`. Key variables:

| Variable | Default | Description |
|---|---|---|
| `kasm_action` | `deploy` | Action to perform |
| `kasm_services` | `[db, web, agent, guac]` | Services to install on this host |
| `kasm_zone` | `zone1` | Zone this host belongs to |
| `proxy_port` | `443` | HTTPS listening port |
| `desired_swap_size` | `5g` | Swap to ensure exists on agent hosts |
| `database_hostname` | `false` | External DB hostname (`false` = local Docker DB) |
| `database_ssl` | `true` | Require SSL for DB connections |
| `start_docker_on_boot` | `true` | Enable Docker at boot |
| `kasm_activation_key_file` | `""` | Licence key filename in `files/` |
| `kasm_enable_lossless` | `false` | Enable lossless streaming |
| `kasm_default_registry_url` | `""` | Override default Workspaces Registry URL |
| `kasm_guac_cluster_size` | `""` | guacd instances (empty = 1 per CPU core) |
| `kasm_no_check_ports` | `false` | Disable installer open-port checks |
| `kasm_no_check_disk` | `false` | Disable installer disk-space checks |
| `kasm_server_cert` | `""` | Path to server certificate (PEM) |
| `kasm_server_key` | `""` | Path to server private key (PEM) |
| `kasm_root_ca` | `""` | Path to custom root CA (required for OIDC provider trust) |
| `kasm_certs_remote` | `false` | `true` if cert files are already on the target host |
| `kasm_restore_file` | `""` | Path to backup tar.gz to restore from |
| `kasm_restore_remote` | `false` | `true` if backup file is already on the target host |

## Licence key

Place your activation key file in `files/` and set the filename in `group_vars` or `host_vars`:

```yaml
kasm_activation_key_file: kasm_activation.key
```

## Certificates

Apply a custom server certificate, private key, and/or root CA:

```bash
# Cert files on the Ansible control node (default)
ansible-playbook -i inventory deploy_and_configure_kasm.yml \
  -e kasm_action=certs \
  -e kasm_server_cert=/path/to/server.crt \
  -e kasm_server_key=/path/to/server.key \
  -e kasm_root_ca=/path/to/ca.crt

# Cert files already on the target host
ansible-playbook -i inventory deploy_and_configure_kasm.yml \
  -e kasm_action=certs \
  -e kasm_certs_remote=true \
  -e kasm_server_cert=/etc/ssl/certs/server.crt \
  -e kasm_server_key=/etc/ssl/private/server.key \
  -e kasm_root_ca=/etc/ssl/certs/ca.crt
```

The root CA is mounted into the `kasm_api` container so that OIDC providers signed by a private CA are trusted. Certificates are reapplied automatically on upgrade.

## Database backup

```bash
ansible-playbook -i inventory deploy_and_configure_kasm.yml -e kasm_action=backup
```

Backups are written to `remote_backup_dir` on the DB host (default `/srv/backup/kasm/`) and retained for `retention_days` days (default `10`).

To fetch backups to the control node:

```bash
ansible-playbook -i inventory deploy_and_configure_kasm.yml \
  -e kasm_action=backup \
  -e local_backup_dir=/path/to/local/backups/
```

## Database restore

```bash
# Backup file on the Ansible control node (default)
ansible-playbook -i inventory deploy_and_configure_kasm.yml \
  -e kasm_action=restore \
  -e kasm_restore_file=/path/to/kasm_db_backup.tar.gz

# Backup file already on the target host
ansible-playbook -i inventory deploy_and_configure_kasm.yml \
  -e kasm_action=restore \
  -e kasm_restore_file=/srv/backup/kasm/kasm_db_backup.tar.gz \
  -e kasm_restore_remote=true
```

Restore only runs on hosts that have `db` in `kasm_services`. All Kasm services are stopped before the restore and restarted afterwards.

## Offline installation

Place the optional offline image tarballs in `files/` alongside the main installer. The role will detect and use them automatically:

- `kasm_release_service_images_*.tar.gz` — core service images
- `kasm_release_workspace_images_*.tar.gz` — workspace images
- `kasmweb_network_plugin_*.tar.gz` — network plugin

## Remote database

To use an external PostgreSQL instance instead of the local Docker DB:

```yaml
# group_vars/all/vars.yml
database_hostname: db.example.com
database_port: 5432
database_user: kasmapp
database_name: kasm
database_ssl: true
init_remote_db: true  # set to false after first deploy
```

## Recovering credentials

If credentials are lost they can be recovered from a running deployment:

```bash
# Database password (on a web host)
sudo grep " password" /opt/kasm/current/conf/app/api/api.app.config.yaml

# Manager token (on an agent host)
sudo grep "token" /opt/kasm/current/conf/app/agent/agent.app.config.yaml
```

## Acknowledgements

This role was originally developed by referencing the official [kasmtech/ansible-kasm](https://github.com/kasmtech/ansible-kasm) project. It has since been independently rewritten with a different structure and feature set, but credit is due for the foundational approach.

## License

MIT — see [LICENSE](LICENSE).
