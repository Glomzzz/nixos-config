{
  username,
  config,
  ...
}:
let
  opencodePasswordFile = config.sops.secrets."opencode/password".path;
  opencodeGoApiKeyFile = config.sops.secrets."opencode/api_key".path;
  ohMyOpenAgentConfig = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/master/assets/oh-my-openagent.schema.json";
    
    # Optimized agent configuration for maximum performance
    # Using DeepSeek V4 Pro for reasoning-heavy agents
    # Using DeepSeek V4 Flash for high-throughput agents (31x more requests)
    agents = {
      # Main orchestrator - highest quality reasoning
      sisyphus = {
        model = "opencode-go/deepseek-v4-pro";
        temperature = 0.1;
      };
      
      # Autonomous deep worker - enabled with non-GPT model support
      # DeepSeek V4 Pro has strong reasoning capabilities
      hephaestus = {
        model = "opencode-go/deepseek-v4-pro";
        allow_non_gpt_model = true;
        temperature = 0.1;
        maxTokens = 8000;
      };
      
      # Strategic planner - high reasoning quality
      prometheus = {
        model = "opencode-go/deepseek-v4-pro";
        temperature = 0.1;
      };
      
      # Pre-planning consultant - good balance
      metis = {
        model = "opencode-go/glm-5";
        temperature = 0.3;
      };
      
      # Plan reviewer - good balance
      momus = {
        model = "opencode-go/glm-5";
        temperature = 0.1;
      };
      
      # Read-only consultant - needs strong reasoning
      oracle = {
        model = "opencode-go/deepseek-v4-pro";
        temperature = 0.1;
      };
      
      # Contextual grep - high throughput, cost-effective
      # DeepSeek V4 Flash: 31,650 req/5h vs Pro: 3,450 req/5h
      explore = {
        model = "opencode-go/deepseek-v4-flash";
        temperature = 0.1;
        textVerbosity = "low";
      };
      
      # External docs/code search - high throughput
      librarian = {
        model = "opencode-go/deepseek-v4-flash";
        temperature = 0.1;
      };
      
      # PDF/image analysis - vision capabilities
      "multimodal-looker" = {
        model = "opencode-go/kimi-k2.5";
        temperature = 0.1;
      };
      
      # Todo-list orchestrator - high throughput
      atlas = {
        model = "opencode-go/deepseek-v4-flash";
        temperature = 0.1;
      };
      
      # Category-spawned executor - high throughput
      "sisyphus-junior" = {
        model = "opencode-go/deepseek-v4-flash";
        temperature = 0.1;
      };
    };
    
    # Category-based model routing for task delegation
    categories = {
      # Complex problem solving - use best reasoning model
      ultrabrain = {
        model = "opencode-go/deepseek-v4-pro";
      };
      # Autonomous research - balance quality and speed
      deep = {
        model = "opencode-go/deepseek-v4-pro";
      };
      # Quick tasks - fastest model
      quick = {
        model = "opencode-go/deepseek-v4-flash";
      };
      # Visual/UI work - good balance
      "visual-engineering" = {
        model = "opencode-go/kimi-k2.5";
      };
      # Writing tasks
      writing = {
        model = "opencode-go/glm-5";
      };
    };
    
    # Fallback models for reliability
    fallback_models = {
      default = [
        "opencode-go/deepseek-v4-pro"
        "opencode-go/kimi-k2.5"
        "opencode-go/glm-5"
      ];
      hephaestus = [
        "opencode-go/deepseek-v4-pro"
        "opencode-go/glm-5"
      ];
    };
    
    # Background task configuration
    background_tasks = {
      max_concurrent = 5;
    };
    
    # LSP integration
    lsp = {
      enabled = true;
    };
  };
  # port = "6112";
in
{
  home-manager.users.${username} = {
    home.sessionVariables.OPENCODE_PASSWORD_FILE = opencodePasswordFile;

    programs.opencode = {
      enable = true;
      # web = {
      #   enable = true;
      #   extraArgs = [
      #     "--hostname"
      #     "127.0.0.1"
      #     "--port"
      #     "${port}"
      #   ];
      # };
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        plugin = [ "oh-my-openagent" ];
        provider = {
          "opencode-go" = {
            options = {
              apiKey = "{file:${opencodeGoApiKeyFile}}";
            };
          };
        };
        agent = {
          build.options.store = false;
          plan.options.store = false;
        };
      };
    };

    xdg.configFile."opencode/oh-my-openagent.json".text = ohMyOpenAgentConfig;
  };

  # services.tailscale.serve.services.opencode = {
  #   endpoints = {
  #     "tcp:${port}" = "http://127.0.0.1:${port}";
  #   };
  #   advertised = true;
  # };
}
