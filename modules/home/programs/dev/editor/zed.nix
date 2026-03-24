{...}: {
  programs.zed-editor = {
    enable = true;
    mutableUserSettings = false;
    mutableUserKeymaps = false;

    userSettings = {
      edit_predictions = {
        provider = "none";
      };
      agent_servers = {
        opencode = {
          type = "registry";
        };
      };
      terminal = {
        shell = {
          program = "nu";
        };
      };
      agent_buffer_font_size = 16.0;
      ui_font_family = "Monocraft";
      buffer_font_family = "Monocraft";
      icon_theme = "Material Icon Theme";
      agent = {
        favorite_models = [];
        inline_assistant_model = {
          provider = "copilot_chat";
          model = "gpt-4o";
          enable_thinking = false;
        };
        model_parameters = [];
      };
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      session = {
        trust_all_worktrees = true;
      };
      vim_mode = false;
      base_keymap = "JetBrains";
      ui_font_size = 17.0;
      buffer_font_size = 16.0;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "Catppuccin Macchiato";
      };
      lsp = {
        tinymist = {
          settings = {
            exportPdf = "onSave";
            outputPath = "$root/$name";
            rootPath = "$root/root/";
          };
        };
      };
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {};
      }
      {
        context = "Editor && vim_mode == insert";
        bindings = {};
      }
      {
        context = "AcpThread > (Editor && !use_modifier_to_send)";
        bindings = {
          enter = null;
        };
      }
      {
        context = "Editor";
        bindings = {
          shift-r = "editor::Rename";
        };
      }
      {
        context = "Editor";
        bindings = {
          shift-f6 = null;
        };
      }
      {
        context = "ProjectPanel";
        bindings = {
          shift-r = "project_panel::Rename";
        };
      }
      {
        context = "ProjectPanel";
        bindings = {
          shift-f6 = null;
        };
      }
    ];
  };
}
