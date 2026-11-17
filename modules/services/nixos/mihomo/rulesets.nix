{pkgs}: let
  # Seed copies of the MetaCubeX rule lists, pinned to one meta-rules-dat commit. The
  # NixOS module copies each one into the state directory when it is missing, so the
  # first start works offline. mihomo's rule-provider interval keeps them current.
  revision = "458e716abd80ff8c6aee2b7d15c4f94b20e9d279";
  fetch = name: file: hash:
    pkgs.fetchurl {
      name = "${name}.list";
      url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/${revision}/geo/${file}.list";
      inherit hash;
    };
in {
  geosite-openai = fetch "geosite-openai" "geosite/openai" "sha256-ik8bFjAviCEX08EG0qwh8QisvUcU3XNz1AN0XA8ziqg=";
  geosite-anthropic = fetch "geosite-anthropic" "geosite/anthropic" "sha256-Me8iuFfaJc37QIC950pIX+1S7MxvwUMRGT+BGUWTjXg=";
  geosite-google-gemini = fetch "geosite-google-gemini" "geosite/google-gemini" "sha256-16UaM9zKsmolJgg28jsCzCg1kM1ThPz5PegsMzHOVqk=";
  geosite-geolocation-not-cn = fetch "geosite-geolocation-not-cn" "geosite/geolocation-!cn" "sha256-cdApiwuZD2avXpoPs/hNsdMaHlXIk03gCh4uuRdPbcY=";
  geosite-cn = fetch "geosite-cn" "geosite/cn" "sha256-cDxwb5Ja+nVqQEE2ziy+qFZ2OWnSQSgM5VNFUZ3JMy8=";
  geosite-steam = fetch "geosite-steam" "geosite/steam" "sha256-OdCQbu4r5QF3HSOZp4kOLyJJXZNfjmCLscPj8twJPBU=";
  geoip-hk = fetch "geoip-hk" "geoip/hk" "sha256-DO74l9IoZ4mF3mMo/szXMHZ6foW6AT3f3XJLRDDYG74=";
  geoip-mo = fetch "geoip-mo" "geoip/mo" "sha256-HfJAo3l/kmU8Rd3uRuv2/iNXUjmkzSZLunupz1zcecM=";
  geoip-cn = fetch "geoip-cn" "geoip/cn" "sha256-7XDl9Qpszh4QMmiUodIKTo8Uo8p/2jopdHSZ+wZZtvw=";
}
