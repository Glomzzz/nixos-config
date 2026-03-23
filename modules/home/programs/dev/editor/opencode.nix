{osConfig, ...}: {
  home.sessionVariables.OPENCODE_OPENAI_API_KEY_FILE = osConfig.sops.secrets."opencode/openai_api_key".path;

  programs.opencode = {
    enable = true;
  };
}
