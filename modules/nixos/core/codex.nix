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
        # NixOS-managed Codex configuration
        # This file is controlled by NixOS home-manager. Do not edit manually.

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

  # Version tracking for codex
  versionConfig = builtins.toJSON {
    version = "0.128.0";
    last_checked = "2026-05-01T12:56:33Z";
  };
in
{
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      codex
      oh-my-codex
    ];

    # Force-manage Codex configuration via NixOS
    home.file.".codex/config.toml".text = codexConfig;

    # Version file to prevent codex from prompting for updates
    home.file.".codex/version.json".text = versionConfig;

    # Execution rules for Codex (allow common Nix/development commands)
    home.file.".codex/rules/default.rules".text = ''
      prefix_rule(pattern=["direnv", "exec", ".", "uv", "run"], decision="allow")
      prefix_rule(pattern=["timeout", "20s", "direnv", "exec", ".", "uv", "run"], decision="allow")
      prefix_rule(pattern=["nix", "eval"], decision="allow")
      prefix_rule(pattern=["nix", "build"], decision="allow")
      prefix_rule(pattern=["nix", "run"], decision="allow")
      prefix_rule(pattern=["git"], decision="allow")
      prefix_rule(pattern=["cargo"], decision="allow")
      prefix_rule(pattern=["npm"], decision="allow")
      prefix_rule(pattern=["pnpm"], decision="allow")
      prefix_rule(pattern=["yarn"], decision="allow")
      prefix_rule(pattern=["just"], decision="allow")
    '';

    # Ensure codex uses apiapi endpoint
    home.sessionVariables.CODEX_BASE_URL = "https://apiapi.chat/v1";

    # Use an inline module to get access to home-manager's config.lib.dag
    imports = [
      (
        { config, ... }:
        {
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
