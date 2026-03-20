# graphics/theme.nix
# Nord theme color mapping and palette generation.
#
# Produces a unified settings attrset consumed by both the Linux
# programs.ghostty module and the Darwin raw config generator.
{ lib }:
let
  # Import canonical Nord palette
  colors = import ../themes/nord/colors.nix;

  # Semantic mapping: numbered Nord names for backward compatibility
  nord = {
    nord0  = colors.polar.night0;
    nord1  = colors.polar.night1;
    nord2  = colors.polar.night2;
    nord3  = colors.polar.night3;
    nord4  = colors.snow.storm0;
    nord5  = colors.snow.storm1;
    nord6  = colors.snow.storm2;
    nord7  = colors.frost.frost0;
    nord8  = colors.frost.frost1;
    nord9  = colors.frost.frost2;
    nord10 = colors.frost.frost3;
    nord11 = colors.aurora.red;
    nord12 = colors.aurora.orange;
    nord13 = colors.aurora.yellow;
    nord14 = colors.aurora.green;
    nord15 = colors.aurora.purple;
  };

  # 16-color terminal palette (ANSI 0–15)
  palette = [
    "0=${nord.nord1}"    # black  (darker than bg for depth)
    "1=${nord.nord11}"   # red    (aurora red)
    "2=${nord.nord14}"   # green  (aurora green)
    "3=${nord.nord13}"   # yellow (aurora yellow)
    "4=${nord.nord10}"   # blue   (frost blue — deeper)
    "5=${nord.nord15}"   # magenta (aurora purple)
    "6=${nord.nord8}"    # cyan   (frost cyan — primary accent)
    "7=${nord.nord5}"    # white  (snow storm)
    "8=${nord.nord3}"    # bright black  (gray)
    "9=${nord.nord11}"   # bright red    (consistent)
    "10=${nord.nord14}"  # bright green  (vibrant)
    "11=${nord.nord13}"  # bright yellow (vibrant)
    "12=${nord.nord9}"   # bright blue   (lighter frost)
    "13=${nord.nord15}"  # bright magenta (purple)
    "14=${nord.nord7}"   # bright cyan   (lightest frost)
    "15=${nord.nord6}"   # bright white  (pure snow)
  ];

  # Generate theme settings from cfg, returning an attrset.
  mkThemeSettings = cfg:
    if cfg.theme.nordTheme && cfg.theme.useBuiltinNord then {
      theme = "nord";
    }
    else if cfg.theme.nordTheme then {
      background           = cfg.theme.customColors.background or nord.nord0;
      foreground           = cfg.theme.customColors.foreground or nord.nord6;
      cursor-color         = cfg.theme.customColors.cursor-color or nord.nord8;
      cursor-text          = cfg.theme.customColors.cursor-text or nord.nord0;
      selection-background = cfg.theme.customColors.selection-background or nord.nord3;
      selection-foreground = cfg.theme.customColors.selection-foreground or nord.nord6;
      inherit palette;
    }
    else {};

in {
  inherit colors nord palette mkThemeSettings;
}
