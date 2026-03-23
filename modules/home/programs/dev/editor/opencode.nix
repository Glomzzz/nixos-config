{osConfig, ...}:
let
  openaiApiKeyFile = osConfig.sops.secrets."opencode/openai_api_key".path;
in {
  home.sessionVariables.OPENCODE_OPENAI_API_KEY_FILE = openaiApiKeyFile;

  programs.opencode = {
    enable = true;
    settings = {
      plugin = [ "oh-my-opencode@latest" ];
      provider = {
        openai = {
          options = {
            baseURL = "http://0.0.0.0:8080/v1";
            apiKey = "{file:${openaiApiKeyFile}}";
          };
          models = {
            "gpt-5-codex" = {
              name = "GPT-5 Codex";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
              };
            };
            "gpt-5.1-codex" = {
              name = "GPT-5.1 Codex";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
              };
            };
            "gpt-5.1-codex-max" = {
              name = "GPT-5.1 Codex Max";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
              };
            };
            "gpt-5.1-codex-mini" = {
              name = "GPT-5.1 Codex Mini";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
              };
            };
            "gpt-5.2" = {
              name = "GPT-5.2";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
                xhigh = { };
              };
            };
            "gpt-5.4" = {
              name = "GPT-5.4";
              limit = {
                context = 1050000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
                xhigh = { };
              };
            };
            "gpt-5.3-codex-spark" = {
              name = "GPT-5.3 Codex Spark";
              limit = {
                context = 128000;
                output = 32000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
                xhigh = { };
              };
            };
            "gpt-5.3-codex" = {
              name = "GPT-5.3 Codex";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
                xhigh = { };
              };
            };
            "gpt-5.2-codex" = {
              name = "GPT-5.2 Codex";
              limit = {
                context = 400000;
                output = 128000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
                xhigh = { };
              };
            };
            "codex-mini-latest" = {
              name = "Codex Mini";
              limit = {
                context = 200000;
                output = 100000;
              };
              options.store = false;
              variants = {
                low = { };
                medium = { };
                high = { };
              };
            };
          };
        };
      };
      agent = {
        build.options.store = false;
        plan.options.store = false;
      };
    };
  };
}
