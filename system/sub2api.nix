{pkgs, lib, ...}: let
  sub2apiVersion = "0.1.104";
  sub2apiSources = {
    "x86_64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${sub2apiVersion}/sub2api_${sub2apiVersion}_linux_amd64.tar.gz";
      sha256 = "sha256-JGqb++t13WpTGzFRYzLBYWsRZrs8JDtgECuKjQ54GKk=";
    };
    "aarch64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${sub2apiVersion}/sub2api_${sub2apiVersion}_linux_arm64.tar.gz";
      sha256 = "sha256-ijhRLHdD9DK7t6KEDU3My9y0fhKvgawT166gWuXx42A=";
    };
  };
  sub2apiSource = lib.attrByPath [pkgs.stdenv.hostPlatform.system] null sub2apiSources;
  sub2api = pkgs.stdenvNoCC.mkDerivation {
    pname = "sub2api";
    version = sub2apiVersion;
    src = pkgs.fetchurl sub2apiSource;
    nativeBuildInputs = [pkgs.gnutar];
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      tar -xzf "$src"
      install -m755 sub2api "$out/bin/sub2api"
      runHook postInstall
    '';
  };
in {
  assertions = [
    {
      assertion = sub2apiSource != null;
      message = "sub2api: unsupported system ${pkgs.stdenv.hostPlatform.system}";
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
      ExecStart = "${sub2api}/bin/sub2api";
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "sub2api";
    };

    environment = {
      DATA_DIR = "/var/lib/sub2api";
    };
  };
}
