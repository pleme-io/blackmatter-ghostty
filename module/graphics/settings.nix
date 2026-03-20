# graphics/settings.nix
# Unified Ghostty settings builder.
#
# Produces a single attrset of all graphical settings that both the
# Linux programs.ghostty module and the Darwin text config use.
# Non-graphical settings (keybindings, behavior, shell integration)
# are composed separately in default.nix.
{ lib }:
let
  theme = import ./theme.nix { inherit lib; };

  # Build the complete graphical settings attrset from cfg.
  mkGraphicsSettings = cfg: lib.mkMerge [
    # ── Font ────────────────────────────────────────────────────
    {
      font-family = cfg.font.family;
      font-size = cfg.font.size;
      font-thicken = cfg.font.thicken;
    }
    (lib.mkIf (cfg.font.adjustCellHeight != 0) {
      adjust-cell-height = "${toString cfg.font.adjustCellHeight}%";
    })

    # ── Window ──────────────────────────────────────────────────
    {
      window-padding-x = cfg.window.paddingX;
      window-padding-y = cfg.window.paddingY;
      window-padding-balance = true;
      window-padding-color = "background";
      window-decoration = cfg.window.decoration;
      window-theme = "auto";
      window-subtitle = "working-directory";
    }

    # ── Appearance ──────────────────────────────────────────────
    {
      background-opacity = cfg.appearance.backgroundOpacity;
      background-blur-radius = cfg.appearance.backgroundBlurRadius;
      unfocused-split-opacity = cfg.appearance.unfocusedSplitOpacity;
      bold-is-bright = cfg.appearance.boldIsBright;
      window-colorspace = cfg.appearance.windowColorspace;
      macos-titlebar-style = cfg.appearance.macosTitlebarStyle;
      font-thicken-strength = cfg.appearance.fontThickenStrength;
    }
    (lib.mkIf (cfg.appearance.unfocusedSplitFill != null) {
      unfocused-split-fill = cfg.appearance.unfocusedSplitFill;
    })

    # ── Cursor ──────────────────────────────────────────────────
    {
      cursor-style = cfg.cursor.style;
      cursor-style-blink = cfg.cursor.blink;
    }

    # ── Theme (Nord palette) ────────────────────────────────────
    (theme.mkThemeSettings cfg)

    # ── Performance ─────────────────────────────────────────────
    {
      window-vsync = cfg.performance.vsync;
      minimum-contrast = cfg.performance.minimumContrast;
    }
  ];

in {
  inherit mkGraphicsSettings;
}
