{
  runCommand,
  v2ray-domain-list-community,
  v2ray-geoip,
}:
runCommand "v2raya-assets" {} ''
  mkdir -p "$out"
  ln -s ${v2ray-geoip}/share/v2ray/geoip.dat "$out/geoip.dat"
  ln -s ${v2ray-domain-list-community}/share/v2ray/geosite.dat "$out/geosite.dat"
''
