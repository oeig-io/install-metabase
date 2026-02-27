# Metabase Container

Deployment automation for Metabase Business Intelligence on NixOS containers.

## Overview

This repository automates Metabase installation using a 3-phase approach:

1. **Phase 1 - NixOS Prerequisites** (`metabase-prerequisites.nix`): Java 17, PostgreSQL 17, metabase user, directories
2. **Phase 2 - Ansible Orchestration** (`ansible/metabase-install.yml`): Download latest Metabase JAR, configure database
3. **Phase 3 - NixOS Service** (`metabase-service.nix`): systemd service with auto-start and firewall rules

> **🔗 Reference**: See [github.com/oeig-io/container-management](https://github.com/oeig-io/container-management) for deployment standards and orchestration instructions.

## Access

- **Web UI**: http://localhost:3000/
- **Default Port**: 3000

Complete the initial setup wizard in the browser on first access.

## Service Management

```bash
# Check status
systemctl status metabase

# Start/Stop/Restart
systemctl start metabase
systemctl stop metabase
systemctl restart metabase

# View logs
journalctl -u metabase -f
```

## Database

Metabase uses PostgreSQL for its own metadata storage. The database credentials are auto-generated and stored in `/home/metabase/.pgpass`.

```bash
# Connect to Metabase database
psqlm

# Or as metabase user
sudo -u metabase psqlm -c "SELECT * FROM core_user;"
```

## Configuration

### Variables

Edit `ansible/vars/metabase.yml` to customize:

- `metabase_port`: Web UI port (default: 3000)
- `db_admin_password`: PostgreSQL admin password

### Version

The playbook automatically fetches the latest Metabase version from GitHub releases. The installed version is stored in `/opt/metabase/VERSION`.

## File Structure

```
metabase-container/
├── install.sh                    # Automated installation script
├── metabase-prerequisites.nix    # NixOS prerequisites module
├── metabase-service.nix          # NixOS service module
├── README.md                     # This file
└── ansible/
    ├── inventory.ini             # Ansible inventory
    ├── metabase-install.yml      # Main Ansible playbook
    └── vars/
        └── metabase.yml          # Configuration variables
```

## Connecting to iDempiere

To connect Metabase to an iDempiere database for reporting:

1. Access Metabase at http://localhost:3000/
2. Complete the initial setup wizard
3. Add a new database connection:
   - Type: PostgreSQL
   - Host: (iDempiere container IP or hostname)
   - Port: 5432
   - Database: idempiere
   - User: idempiere_readonly (for read-only access)
   - Password: (from iDempiere container's /home/idempiere/.pgpass)

## Based On

- https://github.com/chuboe/chuboe-bi-metabase
- https://www.metabase.com/docs/latest/installation-and-operation/running-metabase-on-debian

## References

- [github.com/oeig-io/container-management](https://github.com/oeig-io/container-management) - Deployment standards and orchestration
