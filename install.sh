#!/usr/bin/env bash
# install.sh - Entry point for Metabase installation
#
# Self-contained installer that wraps existing installation steps.
# Executes three phases: prerequisites → ansible → service
#
# Usage: ./install.sh
#
# Assumes:
#   - NixOS base system
#   - Script directory contains metabase-prerequisites.nix, metabase-service.nix, ansible/

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Metabase Installation ==="
echo "Script directory: $SCRIPT_DIR"

# Phase 1: NixOS Prerequisites
echo ""
echo "=== Phase 1: NixOS Prerequisites ==="
if grep -q "metabase-prerequisites.nix" /etc/nixos/configuration.nix; then
    echo "Prerequisites already in configuration.nix, skipping..."
else
    sed -i 's|./incus.nix|./incus.nix\n    '"$SCRIPT_DIR"'/metabase-prerequisites.nix|' /etc/nixos/configuration.nix
fi
sudo nixos-rebuild switch

# Phase 2: Ansible Installation
echo ""
echo "=== Phase 2: Ansible Installation ==="
cd "$SCRIPT_DIR/ansible"
ansible-playbook -i inventory.ini metabase-install.yml \
    --connection=local

# Phase 3: NixOS Service
echo ""
echo "=== Phase 3: NixOS Service ==="
if grep -q "metabase-service.nix" /etc/nixos/configuration.nix; then
    echo "Service already in configuration.nix, skipping..."
else
    sed -i 's|metabase-prerequisites.nix|metabase-prerequisites.nix\n    '"$SCRIPT_DIR"'/metabase-service.nix|' /etc/nixos/configuration.nix
fi
sudo nixos-rebuild switch

echo ""
echo "=== Metabase Installation Complete ==="
echo "Service status: systemctl status metabase"
echo "Web UI: http://localhost:3000/"
