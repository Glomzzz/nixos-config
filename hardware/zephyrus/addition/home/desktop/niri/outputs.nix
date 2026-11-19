# Laptop panel plus the external monitor docked to its right. Split from the
# shared niri settings because eDP-1 exists only on the Zephyrus laptop.
{
  # niri has no X11-style "primary output" flag. The two things that decide
  # which screen behaves as primary are where each output sits in the global
  # coordinate space and which one takes focus at startup, so both are pinned
  # to the laptop panel. Without this niri places outputs automatically and
  # sorts by name, which puts HDMI-A-1 at the origin and hands it the initial
  # focus whenever the dock is attached.
  programs.niri.settings.outputs = {
    # Scales are pinned rather than left to niri's DPI heuristic so the
    # positions below stay valid. 2560x1600 at scale 1.5 is 1706.67 logical
    # pixels wide, so the external monitor starts at x=1707 to sit flush to
    # its right. x=1706 would overlap the panel by a fraction of a pixel, and
    # niri responds to any overlap by discarding both explicit positions and
    # auto-placing instead. Keep this in step if the panel scale changes.
    "eDP-1" = {
      focus-at-startup = true;
      scale = 1.5;
      position = {
        x = 0;
        y = 0;
      };
    };
    "HDMI-A-1" = {
      scale = 1.0;
      position = {
        x = 1707;
        y = 0;
      };
    };
  };
}
