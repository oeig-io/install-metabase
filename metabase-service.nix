# metabase-service.nix
# NixOS module for Metabase systemd service (Phase 2)
#
# IMPORTANT: Only add this AFTER running the Ansible installation playbook!
#
# Workflow:
#   1. Prerequisites installed (metabase-prerequisites.nix)
#   2. Ansible has installed Metabase to /opt/metabase
#   3. Add this to configuration.nix:
#      imports = [ ./metabase-prerequisites.nix ./metabase-service.nix ];
#   4. Run: sudo nixos-rebuild switch
#
# The service will start automatically after rebuild.

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
    host = "localhost";
    port = 5432;
  };

  # Read password from .pgpass file
  # Format: hostname:port:database:username:password
  pgpassFile = "/home/${metabase.user}/.pgpass";

in {
  #############################################################################
  # Firewall - allow Metabase web port
  #############################################################################
  networking.firewall.allowedTCPPorts = [ 3000 ];

  #############################################################################
  # Metabase systemd service
  #############################################################################
  systemd.services.metabase = {
    description = "Metabase Business Intelligence Server";
    after = [ "network.target" "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];

    # Read password from .pgpass and set environment
    script = ''
      # Extract password from .pgpass (format: host:port:db:user:password)
      DB_PASS=$(cut -d: -f5 ${pgpassFile})

      export MB_DB_TYPE=postgres
      export MB_DB_DBNAME=${db.name}
      export MB_DB_PORT=${toString db.port}
      export MB_DB_USER=${db.user}
      export MB_DB_PASS="$DB_PASS"
      export MB_DB_HOST=${db.host}
      export MB_JETTY_HOST=0.0.0.0
      export MB_JETTY_PORT=3000
      export JAVA_HOME=${pkgs.openjdk21}

      cd ${metabase.installDir}
      exec ${pkgs.openjdk21}/bin/java -jar metabase.jar
    '';

    serviceConfig = {
      Type = "simple";
      User = metabase.user;
      Group = metabase.group;
      WorkingDirectory = metabase.installDir;

      Restart = "on-failure";
      RestartSec = "30s";
      TimeoutStartSec = "300";
      TimeoutStopSec = "60";

      # Increase file descriptor limit (Metabase recommendation)
      LimitNOFILE = 10000;

      # Security hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [
        metabase.installDir
        "/var/log/metabase"
        "/tmp"
      ];
      PrivateTmp = true;
    };
  };
}
