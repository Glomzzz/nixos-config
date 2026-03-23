{
  config,
  pkgs,
  ...
}: {
  assertions = [
    {
      assertion = pkgs ? sub2api;
      message = "sub2api package is missing from pkgs";
    }
  ];

  users.groups.sub2api = {};
  users.users.sub2api = {
    isSystemUser = true;
    group = "sub2api";
    home = "/var/lib/sub2api";
    description = "Sub2API service user";
  };

  sops.secrets = {
    "sub2api/db_password" = {
      owner = "postgres";
      group = "postgres";
    };
    "sub2api/jwt_secret" = {};
    "sub2api/totp_encryption_key" = {};
    "sub2api/admin_password" = {};
  };

  sops.templates."sub2api-config.yaml" = {
    owner = "root";
    group = "sub2api";
    mode = "0440";
    content = ''
      server:
        host: "127.0.0.1"
        port: 8080
        mode: "release"
      run_mode: "standard"
      database:
        host: "127.0.0.1"
        port: 5432
        user: "sub2api"
        password: "${config.sops.placeholder."sub2api/db_password"}"
        dbname: "sub2api"
        sslmode: "disable"
      redis:
        host: "127.0.0.1"
        port: 6379
        password: ""
        db: 0
      jwt:
        secret: "${config.sops.placeholder."sub2api/jwt_secret"}"
        expire_hour: 24
      totp:
        encryption_key: "${config.sops.placeholder."sub2api/totp_encryption_key"}"
      default:
        admin_email: "admin@example.com"
        admin_password: "${config.sops.placeholder."sub2api/admin_password"}"
    '';
  };

  environment.etc."sub2api/config.yaml".source = config.sops.templates."sub2api-config.yaml".path;

  services.postgresql = {
    enable = true;
  };

  services.redis.servers."".enable = true;

  systemd.services.sub2api-setup = {
    description = "Prepare Sub2API database role and database";
    after = ["postgresql.service"];
    wants = ["postgresql.service"];
    before = ["sub2api.service"];
    wantedBy = ["sub2api.service"];

    path = [config.services.postgresql.package pkgs.coreutils pkgs.gnugrep];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
    };

    script = ''
      export PGPASSWORD="$(tr -d '\n' < ${config.sops.secrets."sub2api/db_password".path})"

      if ! psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'sub2api'" | grep -q 1; then
        psql -c "CREATE ROLE sub2api LOGIN PASSWORD '$PGPASSWORD'"
      fi

      psql -c "ALTER ROLE sub2api WITH PASSWORD '$PGPASSWORD'"

      if ! psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'sub2api'" | grep -q 1; then
        psql -c "CREATE DATABASE sub2api OWNER sub2api"
      fi

      psql -c "ALTER DATABASE sub2api OWNER TO sub2api"
    '';
  };

  systemd.services.sub2api = {
    description = "Sub2API service";
    after = ["network.target" "postgresql.service" "redis.service" "sub2api-setup.service"];
    wants = ["postgresql.service" "redis.service" "sub2api-setup.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      User = "sub2api";
      Group = "sub2api";
      WorkingDirectory = "/var/lib/sub2api";
      ExecStart = "${pkgs.sub2api}/bin/sub2api";
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "sub2api";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectControlGroups = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      CapabilityBoundingSet = "";
      UMask = "0077";
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET" "AF_INET6"];
    };

    environment = {
      DATA_DIR = "/var/lib/sub2api";
    };
  };
}
