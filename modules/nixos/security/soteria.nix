{lib, ...}: {
  # Soteria is the polkit authentication agent for the niri session. Something
  # has to answer polkit prompts or every privileged action (mounting a disk
  # through udiskie, asusd settings) fails silently with no dialog.
  security.soteria.enable = true;

  # niri-flake ships its own polkit agent unit that runs polkit-kde-agent-1,
  # which drags kdePackages back in after KDE was removed. Two agents racing
  # for the same polkit session is also undefined behaviour: whichever
  # registers last wins and the other one idles. Soteria replaces it.
  systemd.user.services.niri-flake-polkit.enable = lib.mkForce false;
}
