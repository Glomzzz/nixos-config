{
  callPackage,
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  inherit (stdenvNoCC.hostPlatform) system;

  pname = "wechat";
  meta = {
    description = "Messaging and calling app";
    homepage = "https://www.wechat.com/en/";
    downloadPage = "https://linux.weixin.qq.com/en";
    license = lib.licenses.unfree;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    maintainers = with lib.maintainers; [prince213];
    mainProgram = "wechat";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };

  sources = let
    # https://dldir1.qq.com/weixin/mac/mac-release.xml
    any-darwin = let
      version = "4.1.13.8-269576";
      version' = lib.replaceString "-" "_" version;
    in {
      inherit version;
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Mac/xWeChatMac_universal_${version'}.dmg";
        hash = "sha256-XjeSqW+CZpV8JKp5HazsF0D9LIHy3BGH17pw9x4iwcg=";
      };
    };
  in {
    aarch64-darwin = any-darwin;
    x86_64-darwin = any-darwin;
    aarch64-linux = {
      version = "4.1.1";
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.AppImage";
        hash = "sha256-RLHhac3wSS1C9rx3GsA07Tp1EzxSf2LLBMyPtrECnUY=";
      };
    };
    x86_64-linux = {
      version = "4.1.1";
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-XxAvFnlljqurGPDgRr+DnuCKbdVvgXBPh02DLHY3Oz8=";
      };
    };
  };
in
  callPackage (
    if stdenvNoCC.hostPlatform.isDarwin
    then ./darwin.nix
    else ./linux.nix
  ) {
    inherit pname meta;
    inherit (sources.${system} or (throw "Unsupported system: ${system}")) version src;
  }
