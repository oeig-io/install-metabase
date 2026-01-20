# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Metabase BI deployment automation framework for NixOS. It combines NixOS declarative configuration with Ansible orchestration to deploy Metabase with PostgreSQL 17.

## Architecture

The installation follows a 3-phase approach:

1. **Phase 1 - NixOS Prerequisites** (`metabase-prerequisites.nix`): System packages, PostgreSQL, metabase user, directories
2. **Phase 2 - Ansible Orchestration** (`ansible/metabase-install.yml`): Download Metabase JAR, configure database
3. **Phase 3 - NixOS Service** (`metabase-service.nix`): systemd service definition with auto-start and firewall rules

Key design decisions:
- Latest version fetched dynamically from GitHub releases API
- `.pgpass` file is the single source of truth for database credentials (password auto-generated on first boot, persists across rebuilds)
- PostgreSQL used for Metabase's own metadata (not H2 file database)
- Includes NixOS-specific workarounds (e.g., `/bin/bash` symlink creation)

## Key Commands

```bash
# Full installation (runs all 3 phases)
./install.sh

# Phase 1: Apply NixOS prerequisites
sudo nixos-rebuild switch

# Phase 2: Run Ansible deployment
cd ansible
ansible-playbook -i inventory.ini metabase-install.yml --connection=local

# Service management
systemctl status metabase
systemctl start metabase
systemctl stop metabase
journalctl -u metabase -f

# Database access (uses ~/.pgpass credentials)
psqlm
sudo -u metabase psqlm -c "SELECT * FROM core_user;"
```

## File Structure

- `metabase-prerequisites.nix` - NixOS module for system dependencies and PostgreSQL
- `metabase-service.nix` - NixOS systemd service definition
- `install.sh` - Automated installation entry point
- `ansible/metabase-install.yml` - Main Ansible playbook
- `ansible/vars/metabase.yml` - Deployment variables
- `ansible/inventory.ini` - Ansible host configuration

## NixOS-Specific Notes

- `/bin/bash` doesn't exist by default - fixed with activation script in prerequisites
- PostgreSQL `listen_addresses` requires `lib.mkForce` to override
- `sudo nixos-rebuild switch` required even when running as root
- Python 3 is installed for local Ansible execution

## Metabase Configuration

- Installation directory: `/opt/metabase`
- Port: 3000 (HTTP)
- Database: PostgreSQL 17 on localhost:5432
- Environment variables set via systemd service script

## Container Access

See `README.md` for container deployment (incus), installation steps, and running commands as the `metabase` user.

## Reference Documentation

- Metabase Docs: https://www.metabase.com/docs/latest/
- GitHub Releases: https://github.com/metabase/metabase/releases
