{
  username,
  config,
  lib,
  pkgs,
  ...
}:
let
  apiapiApiKeyFile = config.sops.secrets."apiapi/api_key".path;

  # Default model configuration
  defaultModel = "gpt-5.4";

  # All available models via apiapi
  availableModels = [
    "gpt-5"
    "gpt-5-codex"
    "gpt-5-codex-mini"
    "gpt-5.1"
    "gpt-5.1-codex"
    "gpt-5.1-codex-max"
    "gpt-5.2-codex"
    "gpt-5.3-codex"
    "gpt-5.3-codex--1"
    "gpt-5.4"
    "gpt-5.4--1"
    "gpt-5.5"
    "gpt-image-2"
    "claude-haiku-4-5-20251001-thinking"
    "claude-opus-4-5-20251101-thinking"
    "claude-opus-4-6"
    "claude-opus-4-6--1"
    "claude-opus-4-6-thinking"
    "claude-opus-4-7"
    "claude-sonnet-4-5-20250929-thinking"
    "claude-sonnet-4-6"
    "claude-sonnet-4-6--1"
    "claude-sonnet-4-6-thinking"
    "deepseek-v4-flash"
    "deepseek-v4-pro"
    "gemini-3-flash-preview"
    "gemini-3-flash-preview--1"
    "gemini-3.1-pro-preview"
    "gemini-3.1-pro-preview--1"
  ];

  modelComments = lib.concatStringsSep "\n" (map (model: "# - ${model}") availableModels);

  codexConfig = ''
        # Codex configuration seeded by NixOS home-manager
        # Codex may update this file at runtime.

        model_provider = "codex"
        model = "${defaultModel}"
        model_reasoning_effort = "xhigh"
        disable_response_storage = true
        approvals_reviewer = "user"

        [model_providers.codex]
        name = "codex"
        base_url = "https://apiapi.chat/v1"
        wire_api = "responses"

        # Available models via apiapi provider:
    ${modelComments}
  '';
  codexConfigFile = pkgs.writeText "codex-config.toml" codexConfig;

  # Version tracking for codex
  versionConfig = builtins.toJSON {
    version = "0.128.0";
    last_checked = "2026-05-01T12:56:33Z";
  };
  versionConfigFile = pkgs.writeText "codex-version.json" versionConfig;
in
{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      codex
      oh-my-codex
    ];

    # Ensure codex uses apiapi endpoint
    home.sessionVariables.CODEX_BASE_URL = "https://apiapi.chat/v1";

    # Use an inline module to get access to home-manager's config.lib.dag
    imports = [
      (
        { config, ... }:
        {
          # Seed writable Codex state files. Codex mutates these at runtime,
          # so symlinking them into /nix/store breaks settings updates.
          home.activation.codexState = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p /home/${username}/.codex

            if [ ! -e /home/${username}/.codex/config.toml ] || [ -L /home/${username}/.codex/config.toml ]; then
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f /home/${username}/.codex/config.toml
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${codexConfigFile} /home/${username}/.codex/config.toml
            fi

            if [ ! -e /home/${username}/.codex/version.json ] || [ -L /home/${username}/.codex/version.json ]; then
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/rm -f /home/${username}/.codex/version.json
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 600 ${versionConfigFile} /home/${username}/.codex/version.json
            fi
          '';

          # Write auth.json from sops secret during home-manager activation
          home.activation.codexAuth = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            if [ -r ${apiapiApiKeyFile} ]; then
              API_KEY=$(${pkgs.coreutils}/bin/cat ${apiapiApiKeyFile})
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p /home/${username}/.codex
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/echo "{\"OPENAI_API_KEY\":\"$API_KEY\"}" > /home/${username}/.codex/auth.json
              $DRY_RUN_CMD ${pkgs.coreutils}/bin/chmod 600 /home/${username}/.codex/auth.json
            else
              echo "Warning: apiapi/api_key secret not available at ${apiapiApiKeyFile}" >&2
            fi
          '';
        }
      )
    ];
  };
}
