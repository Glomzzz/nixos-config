{
  pkgs,
  config,
  ...
}: {
  users.groups.sub2api = {};
  users.users.sub2api = {
    isSystemUser = true;
    group = "sub2api";
    home = "/var/lib/sub2api";
    description = "Sub2API service user";
  };

  sops.templates."sub2api-config.yaml" = {
    owner = "sub2api";
    group = "sub2api";
    mode = "0400";
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
        admin_email: "glom@skillw.com"
        admin_password: "${config.sops.placeholder."sub2api/admin_password"}"
    '';
  };

  environment.etc."sub2api/config.yaml".source = config.sops.templates."sub2api-config.yaml".path;

  services.postgresql = {
    enable = true;
    ensureDatabases = ["sub2api"];
    ensureUsers = [
      {
        name = "sub2api";
        ensureDBOwnership = true;
      }
    ];
  };
  systemd.services.sub2api-db-password = {
    description = "Prepare Sub2API database password";
    after = [
      "postgresql.service"
      "postgresql-setup.service"
    ];
    requires = [
      "postgresql.service"
      "postgresql-setup.service"
    ];
    before = ["sub2api.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      Group = "postgres";
      RemainAfterExit = true;
    };

    path = [
      config.services.postgresql.package
      pkgs.coreutils
    ];

    script = ''
      db_password="$(tr -d '\n' < ${config.sops.secrets."sub2api/db_password".path})"

      psql --dbname postgres \
        -v ON_ERROR_STOP=1 \
        --set=db_password="$db_password" \
        -c "ALTER ROLE sub2api WITH PASSWORD '$db_password';"
    '';
  };

  services.redis.servers."" = {
    enable = true;
  };

  systemd.services.sub2api = {
    description = "Sub2API service";
    requires = [
      "postgresql.service"
      "postgresql-setup.service"
      "sub2api-db-password.service"
      "redis.service"
    ];
    after = [
      "network.target"
      "postgresql.service"
      "postgresql-setup.service"
      "sub2api-db-password.service"
      "redis.service"
    ];
    wants = [
      "postgresql.service"
      "postgresql-setup.service"
      "redis.service"
    ];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      User = "sub2api";
      Group = "sub2api";
      WorkingDirectory = "/var/lib/sub2api";
      ExecStart = "${pkgs.sub2api}/bin/sub2api";
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "sub2api";
    };

    environment = {
      DATA_DIR = "/var/lib/sub2api";
    };
  };

  sops.secrets = {
    "sub2api/db_password" = {
      owner = "postgres";
      group = "postgres";
    };
    "sub2api/jwt_secret" = {
      owner = "sub2api";
      group = "sub2api";
    };
    "sub2api/totp_encryption_key" = {
      owner = "sub2api";
      group = "sub2api";
    };
    "sub2api/admin_password" = {
      owner = "sub2api";
      group = "sub2api";
    };
  };
}
