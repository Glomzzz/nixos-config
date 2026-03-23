{inputs, ...}:
{
  ##################################################################################################################
  #
  # All Glom's Home Manager Configuration
  #
  ##################################################################################################################

  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
    ../../modules/home
  ];

  home.enableNixpkgsReleaseCheck = false;
  # home.sessionVariables = {
  #   OPENCLAW_BUNDLED_PLUGINS_DIR = "${pkgs.openclaw-gateway}/lib/openclaw/extensions";
  # };

  # programs.openclaw = {
  #   enable = true;
  #   documents = inputs.openclaw-local + "/documents";
  #   excludeTools = [
  #     "nodejs_22"
  #     "pnpm_10"
  #   ];
  #   config = {
  #     secrets = {
  #       providers = {
  #         sub2api = {
  #           source = "env";
  #           allowlist = [ "SUB2API_API_KEY" ];
  #         };
  #       };
  #     };
  #   };
  #   instances.default = {
  #     enable = true;
  #     plugins = [ ];
  #     config = {
  #       agents = {
  #         defaults = {
  #           model = "sub2api/gpt-5.4";
  #           heartbeat = {
  #             every = "1m";
  #             target = "telegram";
  #             to = "7384149474";
  #             prompt = "Check typsite development status and send one short Telegram status line each run. Include a unique unix timestamp like ts=<unix_seconds>.";
  #           };
  #         };
  #       };
  #
  #       models = {
  #         providers = {
  #           sub2api = {
  #             baseUrl = "http://127.0.0.1:8080/v1";
  #             auth = "api-key";
  #             api = "openai-responses";
  #             apiKey = {
  #               source = "env";
  #               id = "SUB2API_API_KEY";
  #               provider = "sub2api";
  #             };
  #             models = [
  #               {
  #                 id = "gpt-5-codex";
  #                 name = "GPT-5 Codex";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.1-codex";
  #                 name = "GPT-5.1 Codex";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.1-codex-max";
  #                 name = "GPT-5.1 Codex Max";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.1-codex-mini";
  #                 name = "GPT-5.1 Codex Mini";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.2";
  #                 name = "GPT-5.2";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.4";
  #                 name = "GPT-5.4";
  #                 contextWindow = 1050000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.3-codex-spark";
  #                 name = "GPT-5.3 Codex Spark";
  #                 contextWindow = 128000;
  #                 maxTokens = 32000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.3-codex";
  #                 name = "GPT-5.3 Codex";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "gpt-5.2-codex";
  #                 name = "GPT-5.2 Codex";
  #                 contextWindow = 400000;
  #                 maxTokens = 128000;
  #                 input = [ "text" ];
  #               }
  #               {
  #                 id = "codex-mini-latest";
  #                 name = "Codex Mini";
  #                 contextWindow = 200000;
  #                 maxTokens = 100000;
  #                 input = [ "text" ];
  #               }
  #             ];
  #           };
  #         };
  #       };
  #
  #       secrets = {
  #         providers = {
  #           sub2api = {
  #             source = "env";
  #             allowlist = [ "SUB2API_API_KEY" ];
  #           };
  #         };
  #       };
  #
  #       gateway = {
  #         mode = "local";
  #       };
  #
  #       channels.telegram = {
  #         tokenFile = "/home/glom/.secrets/telegram-bot-token";
  #         allowFrom = [ 7384149474 ];
  #         dmPolicy = "allowlist";
  #         groups = {
  #           "*" = {
  #             requireMention = true;
  #           };
  #         };
  #       };
  #
  #     };
  #   };
  # };
  #
  # home.file.".openclaw/openclaw.json".force = true;
  # home.file.".openclaw/workspace/HEARTBEAT.md" = lib.mkForce {
  #   force = true;
  #   text = ''
  #     Check whether typsite development needs attention.
  #     Always send one short status line to Telegram on every run.
  #     The line must include a unique Unix timestamp in seconds: ts=<unix_seconds>.
  #     If nothing needs attention, send exactly: HEARTBEAT_OK ts=<unix_seconds>
  #     If something needs attention, send one short alert line and include ts=<unix_seconds>.
  #   '';
  # };
  #
  # systemd.user.services.openclaw-gateway.Service.EnvironmentFile = "/home/glom/.secrets/openclaw.env";
  # systemd.user.services.openclaw-gateway.Service.Environment = [
  #   "OPENCLAW_BUNDLED_PLUGINS_DIR=${pkgs.openclaw-gateway}/lib/openclaw/extensions"
  # ];
}
