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
      version = "4.1.15.20-270100";
      version' = lib.replaceString "-" "_" version;
    in {
      inherit version;
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Mac/xWeChatMac_universal_${version'}.dmg";
        hash = "sha256-tzMZ6j739fL28UA7C+2HrHW19bcPCVHqYbrS2USYV/g=";
      };
    };
  in {
    aarch64-darwin = any-darwin;
    x86_64-darwin = any-darwin;
    aarch64-linux = {
      version = "4.1.13";
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_arm64.AppImage";
        hash = "sha256-zihf1qzRuhY2oKSP3qqIm3bS3/xWZRjRpfONxDe6kRc=";
      };
    };
    x86_64-linux = {
      version = "4.1.13";
      src = fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-T1StKQLs1vb9xWgLc1R/gNVCO/RwsBI3pXmi5bPK7us=";
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
