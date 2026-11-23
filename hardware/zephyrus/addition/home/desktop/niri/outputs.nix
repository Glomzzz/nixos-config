# Laptop panel plus the external monitors: the LG stacked above it, or another
# monitor on HDMI-A-1 to its right. Split from the shared niri settings because
# eDP-1 exists only on the Zephyrus laptop.
{
  # niri has no X11-style "primary output" flag. The two things that decide
  # which screen behaves as primary are where each output sits in the global
  # coordinate space and which one takes focus at startup, so both are pinned
  # to the laptop panel. Without this niri places outputs automatically and
  # sorts by name, which can hand the initial focus to the external monitor
  # whenever the dock is attached.
  programs.niri.settings.outputs = {
    # Scales are pinned rather than left to niri's DPI heuristic so the
    # positions below stay valid. 2560x1600 at scale 1.5 is 1706.67 logical
    # pixels wide. Overlapping outputs make niri discard explicit positions and
    # auto-place everything, so keep the positions non-overlapping.
    "eDP-1" = {
      focus-at-startup = true;
      scale = 1.5;
      position = {
        x = 0;
        y = 0;
      };
    };
    # The LG is matched by make, model and serial from `niri msg outputs`, so
    # this rule only applies when the LG is the monitor on HDMI-A-1. The LG
    # (3840x2160) at scale 1.5 is 2560x1440 logical pixels, so y = -1440 stacks
    # it directly on top of eDP-1 (top edge y = 0). x = 0 aligns the left edges.
    # Adjust x to center it (about -427).
    "LG Electronics LG HDR 4K 0x0000B0DC" = {
      scale = 1.5;
      position = {
        x = 0;
        y = -1440;
      };
    };
    # Any other monitor on the HDMI-A-1 port. niri uses the first output block
    # that matches and emits blocks in name order, so the LG block above must
    # come first. The key is lowercase, which sorts after it; connector names
    # match case-insensitively, so this still matches HDMI-A-1.
    "hdmi-a-1" = {
      scale = 1.0;
      position = {
        x = 1707;
        y = 0;
      };
    };
  };
}
