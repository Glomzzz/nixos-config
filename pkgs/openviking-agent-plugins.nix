{
  lib,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "openviking-agent-plugins";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    rev = "daf5fb1774fa33804ffaed7b6f445340de59296c";
    sparseCheckout = ["agent-plugins"];
    hash = "sha256-eUo1otQEaIzyub918fCxz/cfLGIF3MO6SXqYxa34cAQ=";
  };

  # OpenViking's Python server is intentionally not vendored here: this
  # package is the official zero-dependency Agent Plugins/MCP integration.
  # The server still needs its own model configuration and can run locally or
  # in the upstream Docker image.
  nativeBuildInputs = [
    makeWrapper
    nodejs
  ];

  dontBuild = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cd agent-plugins
    node --test plugin.test.mjs
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    cd "$NIX_BUILD_TOP/source"
    pluginRoot="$out/share/openviking/agent-plugins"
    mkdir -p "$pluginRoot"
    cp -R agent-plugins/. "$pluginRoot/"
    substituteInPlace "$pluginRoot/mcp.json" \
      --replace-fail '"command": "node"' '"command": "${nodejs}/bin/node"'
    makeWrapper ${nodejs}/bin/node "$out/bin/openviking-mcp-proxy" \
      --add-flags "$pluginRoot/servers/mcp-proxy.mjs"
    runHook postInstall
  '';

  meta = {
    description = "OpenViking Agent Plugins 1.0 package with its MCP proxy and memory skill";
    homepage = "https://github.com/volcengine/OpenViking/tree/main/agent-plugins";
    license = lib.licenses.agpl3Only;
    mainProgram = "openviking-mcp-proxy";
    platforms = lib.platforms.unix;
  };
}
