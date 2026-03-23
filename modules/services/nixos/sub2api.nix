{pkgs, ...}: {
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

  environment.etc."sub2api/config.yaml".text = ''
    server:
      host: "0.0.0.0"
      port: 8080
      mode: "release"
    run_mode: "standard"
    database:
      host: "127.0.0.1"
      port: 5432
      user: "sub2api"
      password: "sub2api-pass"
      dbname: "sub2api"
      sslmode: "disable"
    redis:
      host: "127.0.0.1"
      port: 6379
      password: ""
      db: 0
    jwt:
      secret: "change-me-please"
      expire_hour: 24
    totp:
      encryption_key: ""
    default:
      admin_email: "admin@example.com"
      admin_password: "admin123"
  '';

  services.postgresql = {
    enable = true;
    ensureDatabases = ["sub2api"];
    ensureUsers = [
      {
        name = "sub2api";
        ensureDBOwnership = true;
        ensureClauses = {
          password = "sub2api-pass";
        };
      }
    ];
  };

  services.redis.enable = true;

  systemd.services.sub2api = {
    description = "Sub2API service";
    after = ["network.target" "postgresql.service" "redis.service"];
    wants = ["postgresql.service" "redis.service"];
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
}
