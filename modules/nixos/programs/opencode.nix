{
  username,
  config,
  ...
}: let
  opencodePasswordFile = config.sops.secrets."opencode/password".path;
  skillwApiKeyFile = config.sops.secrets."skillw/api_key".path;
  mkMultimodalModel = name: output: {
    inherit name;
    attachment = true;
    reasoning = true;
    limit = {
      context = 1000000;
      inherit output;
    };
    modalities = {
      input = ["text" "image"];
      output = ["text"];
    };
  };
  omoConfig = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/omo.schema.json";

    "[opencode]" = {
      agents = {
        sisyphus = {
          model = "skillw/claude-opus-5";
          fallback_models = [
            "skillw/claude-sonnet-5"
            "skillw/claude-opus-4-8"
            "skillw/gpt-5.6-sol"
          ];
          ultrawork.model = "skillw/claude-opus-5-thinking";
        };

        hephaestus = {
          model = "skillw/gpt-5.6-sol-thinking";
          fallback_models = ["skillw/gpt-5.6-sol"];
        };

        prometheus = {
          model = "skillw/claude-fable-5";
          fallback_models = [
            "skillw/claude-opus-5-thinking"
            "skillw/claude-sonnet-5"
          ];
        };

        metis = {
          model = "skillw/claude-opus-5-thinking";
          fallback_models = [
            "skillw/claude-opus-5"
            "skillw/claude-fable-5"
          ];
        };

        momus = {
          model = "skillw/gpt-5.6-terra-thinking";
          fallback_models = [
            "skillw/gpt-5.6-terra"
            "skillw/gpt-5.6-sol-thinking"
            "skillw/claude-opus-5-thinking"
          ];
        };

        oracle = {
          model = "skillw/gpt-5.6-sol-thinking";
          fallback_models = [
            "skillw/gpt-5.6-sol"
            "skillw/claude-opus-5-thinking"
          ];
        };

        explore = {
          model = "skillw/deepseek-v4-flash";
          fallback_models = ["skillw/gpt-5.6-luna"];
          textVerbosity = "low";
        };

        librarian = {
          model = "skillw/deepseek-v4-flash";
          fallback_models = ["skillw/gpt-5.6-luna"];
        };

        "multimodal-looker" = {
          model = "skillw/claude-sonnet-5";
          fallback_models = [
            "skillw/claude-opus-5"
            "skillw/gpt-5.6-sol"
          ];
        };

        atlas = {
          model = "skillw/claude-sonnet-5";
          fallback_models = [
            "skillw/claude-sonnet-4-8"
            "skillw/gpt-5.6-sol"
          ];
        };

        "sisyphus-junior" = {
          model = "skillw/claude-sonnet-5";
          fallback_models = [
            "skillw/claude-sonnet-4-8"
            "skillw/gpt-5.6-terra"
          ];
        };
      };

      categories = {
        "visual-engineering" = {
          model = "skillw/claude-opus-5-thinking";
          fallback_models = [
            "skillw/claude-opus-5"
            "skillw/claude-sonnet-5"
          ];
        };

        ultrabrain = {
          model = "skillw/gpt-5.6-sol-thinking";
          fallback_models = [
            "skillw/gpt-5.6-sol"
            "skillw/gpt-5.6-terra-thinking"
          ];
        };

        deep = {
          model = "skillw/gpt-5.6-sol-thinking";
          fallback_models = [
            "skillw/gpt-5.6-sol"
            "skillw/gpt-5.6-terra-thinking"
          ];
        };

        artistry = {
          model = "skillw/claude-fable-5";
          fallback_models = [
            "skillw/claude-opus-5-thinking"
            "skillw/claude-sonnet-5"
          ];
        };

        quick = {
          model = "skillw/deepseek-v4-flash";
          fallback_models = [
            "skillw/gpt-5.6-luna"
            "skillw/claude-sonnet-4-8"
          ];
        };

        "unspecified-low" = {
          model = "skillw/gpt-5.6-luna";
          fallback_models = [
            "skillw/gpt-5.6-luna-thinking"
            "skillw/deepseek-v4-flash"
          ];
        };

        "unspecified-high" = {
          model = "skillw/claude-opus-5";
          fallback_models = [
            "skillw/gpt-5.6-sol-thinking"
            "skillw/claude-sonnet-5"
          ];
        };

        writing = {
          model = "skillw/claude-sonnet-5";
          fallback_models = [
            "skillw/claude-sonnet-4-8"
            "skillw/gpt-5.6-luna"
          ];
        };
      };

      background_task = {
        defaultConcurrency = 5;
        providerConcurrency.skillw = 5;
        modelConcurrency = {
          "skillw/claude-opus-5-thinking" = 2;
          "skillw/gpt-5.6-sol-thinking" = 2;
          "skillw/gpt-5.6-terra-thinking" = 3;
        };
      };

      runtime_fallback = {
        enabled = true;
        max_fallback_attempts = 4;
        cooldown_seconds = 15;
        timeout_seconds = 30;
        notify_on_fallback = true;
      };
    };
  };
in {
  home-manager.users.${username} = {
    home.sessionVariables.OPENCODE_PASSWORD_FILE = opencodePasswordFile;

    programs.opencode = {
      enable = true;
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        plugin = ["oh-my-openagent"];
        enabled_providers = ["skillw"];
        model = "skillw/claude-opus-5";
        small_model = "skillw/deepseek-v4-flash";
        provider = {
          skillw = {
            npm = "@ai-sdk/openai-compatible";
            name = "SkillW";
            options = {
              apiKey = "{file:${skillwApiKeyFile}}";
              baseURL = "https://api.skillw.com/v1";
            };
            models = {
              "claude-fable-5" = mkMultimodalModel "Claude Fable 5" 128000;
              "claude-opus-4-8" = mkMultimodalModel "Claude Opus 4.8" 128000;
              "claude-opus-5" = mkMultimodalModel "Claude Opus 5" 128000;
              "claude-opus-5-thinking" = mkMultimodalModel "Claude Opus 5 Thinking" 128000;
              "claude-sonnet-4-8" = mkMultimodalModel "Claude Sonnet 4.8" 64000;
              "claude-sonnet-5" = mkMultimodalModel "Claude Sonnet 5" 64000;
              "deepseek-v4-flash" = {
                name = "DeepSeek V4 Flash";
                reasoning = true;
                temperature = true;
                limit = {
                  context = 1000000;
                  output = 32768;
                };
                modalities = {
                  input = ["text"];
                  output = ["text"];
                };
              };
              "gpt-5.6-luna" = mkMultimodalModel "GPT-5.6 Luna" 128000;
              "gpt-5.6-luna-thinking" = mkMultimodalModel "GPT-5.6 Luna Thinking" 128000;
              "gpt-5.6-terra" = mkMultimodalModel "GPT-5.6 Terra" 128000;
              "gpt-5.6-terra-thinking" = mkMultimodalModel "GPT-5.6 Terra Thinking" 128000;
              "gpt-5.6-sol" = mkMultimodalModel "GPT-5.6 Sol" 128000;
              "gpt-5.6-sol-thinking" = mkMultimodalModel "GPT-5.6 Sol Thinking" 128000;
            };
          };
        };
        agent = {
          build.options.store = false;
          plan.options.store = false;
        };
      };
    };

    home.file.".omo/omo.jsonc" = {
      force = true;
      text = omoConfig;
    };
  };
}
