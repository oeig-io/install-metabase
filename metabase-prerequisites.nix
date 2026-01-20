# metabase-prerequisites.nix
# NixOS module for Metabase BI prerequisites (Phase 1)
# Based on: https://github.com/chuboe/chuboe-bi-metabase
#
# This module sets up:
#   - Java (OpenJDK 21)
#   - PostgreSQL 17 (for Metabase's own metadata)
#   - metabase user/group
#   - Required directories
#
# Workflow:
#   1. Add this to configuration.nix: imports = [ ./metabase-prerequisites.nix ];
#   2. Run: sudo nixos-rebuild switch
#   3. Run Ansible: ansible-playbook -i inventory.ini metabase-install.yml --connection=local
#   4. Add service: imports = [ ./metabase-prerequisites.nix ./metabase-service.nix ];
#   5. Run: sudo nixos-rebuild switch

{ config, pkgs, lib, ... }:

let
  metabase = {
    user = "metabase";
    group = "metabase";
    installDir = "/opt/metabase";
  };

  db = {
    name = "metabase";
    user = "metabase";
    # Password is generated randomly at first boot - see activationScripts.pgpass
    host = "localhost";
    port = 5432;
  };

  # Wrapper script to connect to Metabase database (uses ~/.pgpass for auth)
  psqlm = pkgs.writeShellScriptBin "psqlm" ''
    exec ${pkgs.postgresql_17}/bin/psql \
      -h ${db.host} \
      -p ${toString db.port} \
      -U ${db.user} \
      -d ${db.name} \
      "$@"
  '';

in {
  #############################################################################
  # Compatibility: Scripts may expect /bin/bash
  # NixOS doesn't have /bin/bash by default
  #############################################################################
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Create .pgpass for metabase user (required for psqlm and other pg tools)
  # Password is generated randomly on first run and persisted across rebuilds
  system.activationScripts.pgpass = ''
    PGPASS_FILE="/home/${metabase.user}/.pgpass"

    # Only generate password if .pgpass doesn't exist
    if [ ! -f "$PGPASS_FILE" ]; then
      # Generate a random 32-character alphanumeric password
      DB_PASSWORD=$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -dc 'a-zA-Z0-9' | ${pkgs.coreutils}/bin/head -c 32)
      echo "${db.host}:${toString db.port}:${db.name}:${db.user}:$DB_PASSWORD" > "$PGPASS_FILE"
      chown ${metabase.user}:${metabase.group} "$PGPASS_FILE"
      chmod 600 "$PGPASS_FILE"
      echo "Generated new database password in $PGPASS_FILE"
    else
      echo "Using existing database password from $PGPASS_FILE"
    fi
  '';

  #############################################################################
  # System packages - Prerequisites
  #############################################################################
  environment.systemPackages = with pkgs; [
    # JDK 21 - required for Metabase 0.58+
    openjdk21

    # PostgreSQL client tools (psql, pg_dump, etc.)
    postgresql_17

    # Utilities needed for installation
    wget
    curl
    coreutils

    # Python (required for Ansible to work locally)
    python3

    # Ansible for orchestration (run from this machine or control node)
    ansible

    # Quick connect to Metabase database (psqlm)
    psqlm
  ];

  #############################################################################
  # Java environment - OpenJDK 21 LTS (required for Metabase 0.58+)
  #############################################################################
  programs.java = {
    enable = true;
    package = pkgs.openjdk21;
  };

  # Ensure JAVA_HOME is set system-wide
  environment.variables = {
    JAVA_HOME = "${pkgs.openjdk21}";
  };

  #############################################################################
  # PostgreSQL 17 service
  # Used for Metabase's own metadata storage
  #############################################################################
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    # Listen on localhost only
    enableTCPIP = true;
    settings = {
      port = db.port;
      listen_addresses = lib.mkForce "localhost";
    };

    # Authentication - scram-sha-256
    authentication = lib.mkForce ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      # Local connections
      local   all             postgres                                peer
      local   all             all                                     scram-sha-256
      # IPv4 local connections
      host    all             all             127.0.0.1/32            scram-sha-256
      # IPv6 local connections
      host    all             all             ::1/128                 scram-sha-256
    '';
  };

  #############################################################################
  # Metabase system user
  #############################################################################
  users.users.${metabase.user} = {
    isSystemUser = true;
    group = metabase.group;
    home = "/home/${metabase.user}";
    createHome = true;
    shell = pkgs.bash;
    description = "Metabase BI service user";
  };

  users.groups.${metabase.group} = {};

  #############################################################################
  # Metabase directories
  #############################################################################
  systemd.tmpfiles.rules = [
    # Create install directory owned by metabase user
    "d ${metabase.installDir} 0755 ${metabase.user} ${metabase.group} -"
    # Plugins directory
    "d ${metabase.installDir}/plugins 0755 ${metabase.user} ${metabase.group} -"
    # Log directory
    "d /var/log/metabase 0755 ${metabase.user} ${metabase.group} -"
  ];

  #############################################################################
  # Firewall - Uncomment to open Metabase port
  #############################################################################
  # networking.firewall.allowedTCPPorts = [
  #   3000   # Metabase HTTP
  # ];
}
