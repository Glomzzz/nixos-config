{pkgs, ...}: {
  home.packages = with pkgs; [
    typst
    # Zotero currently requires end-of-life Firefox ESR 140. Keep it excluded
    # until upstream moves to a supported runtime; existing user data is untouched.
  ];
}
