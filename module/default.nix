# module/default.nix
# Ghostty terminal emulator - Fast, GPU-accelerated terminal
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.ghostty;

  # Import shared Nord palette
  colors = import ./themes/nord/colors.nix;

  # Map shared colors to numbered Nord names for backward compat
  nord = {
    nord0 = colors.polar.night0;
    nord1 = colors.polar.night1;
    nord2 = colors.polar.night2;
    nord3 = colors.polar.night3;
    nord4 = colors.snow.storm0;
    nord5 = colors.snow.storm1;
    nord6 = colors.snow.storm2;
    nord7 = colors.frost.frost0;
    nord8 = colors.frost.frost1;
    nord9 = colors.frost.frost2;
    nord10 = colors.frost.frost3;
    nord11 = colors.aurora.red;
    nord12 = colors.aurora.orange;
    nord13 = colors.aurora.yellow;
    nord14 = colors.aurora.green;
    nord15 = colors.aurora.purple;
  };

  # ── Derived shader values ────────────────────────────────────────
  builtinShaders =
    (lib.optional cfg.shaders.bloom ./shaders/bloom.glsl)
    ++ (lib.optional cfg.shaders.cursorGlow ./shaders/cursor-glow.glsl)
    ++ (lib.optional cfg.shaders.cursorTrail ./shaders/cursor-trail.glsl)
    ++ (lib.optional cfg.shaders.promptSaber ./shaders/prompt-saber.glsl)
    ++ (lib.optional cfg.shaders.filmGrain ./shaders/film-grain.glsl)
    ++ (lib.optional cfg.shaders.chromaticAberration ./shaders/chromatic-aberration.glsl);

  allShaderPaths = builtinShaders ++ cfg.shaders.custom;

  # ── Debug overrides: cranked-up values for visual verification ──
  debugOverrides = {
    "bloom.glsl" = builtins.replaceStrings
      [
        "BLOOM_INTENSITY  = 0.20"
        "BLOOM_RADIUS     = 5.0"
        "SCAN_INTENSITY   = 0.025"
        "VIGNETTE_STRENGTH = 0.18"
        "PULSE_AMOUNT = 0.015"
      ]
      [
        "BLOOM_INTENSITY  = 0.80"
        "BLOOM_RADIUS     = 12.0"
        "SCAN_INTENSITY   = 0.20"
        "VIGNETTE_STRENGTH = 0.60"
        "PULSE_AMOUNT = 0.12"
      ]
      (builtins.readFile ./shaders/bloom.glsl);

    "film-grain.glsl" = builtins.replaceStrings
      [ "GRAIN_INTENSITY  = 0.025" "FROST_TINT       = 0.15" ]
      [ "GRAIN_INTENSITY  = 0.25"  "FROST_TINT       = 0.80" ]
      (builtins.readFile ./shaders/film-grain.glsl);

    "chromatic-aberration.glsl" = builtins.replaceStrings
      [ "MAX_OFFSET    = 1.5" "FROST_SHIFT   = 0.12" ]
      [ "MAX_OFFSET    = 10.0" "FROST_SHIFT   = 0.50" ]
      (builtins.readFile ./shaders/chromatic-aberration.glsl);

    "cursor-glow.glsl" = builtins.replaceStrings
      [ "CORE_INTENSITY  = 0.70" "INNER_INTENSITY = 0.12" "OUTER_RADIUS = 42.0" ]
      [ "CORE_INTENSITY  = 1.0"  "INNER_INTENSITY = 0.40" "OUTER_RADIUS = 70.0" ]
      (builtins.readFile ./shaders/cursor-glow.glsl);

    "cursor-trail.glsl" = builtins.replaceStrings
      [ "CORE_INTENSITY  = 0.95" "MID_INTENSITY   = 0.18" "OUTER_RADIUS = 32.0" ]
      [ "CORE_INTENSITY  = 1.0"  "MID_INTENSITY   = 0.50" "OUTER_RADIUS = 60.0" ]
      (builtins.readFile ./shaders/cursor-trail.glsl);

    "prompt-saber.glsl" = builtins.replaceStrings
      [ "CORE_INTENSITY  = 0.85" "INNER_INTENSITY = 0.28" "OUTER_HALF  = 24.0" "FOCAL_INTENSITY = 0.12" ]
      [ "CORE_INTENSITY  = 1.0"  "INNER_INTENSITY = 0.50" "OUTER_HALF  = 35.0" "FOCAL_INTENSITY = 0.30" ]
      (builtins.readFile ./shaders/prompt-saber.glsl);
  };

  # ── Derived keybinding values ────────────────────────────────────
  promptNavBinds = lib.optionals cfg.keybindings.promptNavigation [
    "cmd+up=jump_to_prompt:-1"
    "cmd+down=jump_to_prompt:1"
  ];

  splitBinds = lib.optionals cfg.keybindings.splitManagement [
    "ctrl+shift+up=resize_split:up,10"
    "ctrl+shift+down=resize_split:down,10"
    "ctrl+shift+left=resize_split:left,10"
    "ctrl+shift+right=resize_split:right,10"
    "cmd+shift+enter=toggle_split_zoom"
    "cmd+shift+e=equalize_splits"
  ];

  quickTermBinds = lib.optionals cfg.keybindings.quickTerminal [
    "global:cmd+grave_accent=toggle_quick_terminal"
  ];

  allKeybinds = promptNavBinds ++ splitBinds ++ quickTermBinds ++ cfg.keybindings.custom;
in {
  options.blackmatter.components.ghostty = {
    enable = mkEnableOption "Ghostty terminal emulator";

    font = {
      family = mkOption {
        type = types.str;
        default = "JetBrains Mono";
        description = "Font family for terminal";
        example = "FiraCode Nerd Font";
      };

      size = mkOption {
        type = types.int;
        default = 12;
        description = "Font size";
      };

      thicken = mkOption {
        type = types.bool;
        default = true;
        description = "Enable font thickening for better readability";
      };

      adjustCellHeight = mkOption {
        type = types.int;
        default = 0;
        description = "Adjust cell height for line spacing breathing room (in %)";
      };
    };

    window = {
      paddingX = mkOption {
        type = types.int;
        default = 12;
        description = "Horizontal window padding in pixels";
      };

      paddingY = mkOption {
        type = types.int;
        default = 12;
        description = "Vertical window padding in pixels";
      };

      decoration = mkOption {
        type = types.bool;
        default = true;
        description = "Enable window decorations";
      };

      gtkTitlebar = mkOption {
        type = types.bool;
        default = true;
        description = "Use GTK titlebar (Linux only)";
      };
    };

    appearance = {
      backgroundOpacity = mkOption {
        type = types.float;
        default = 0.95;
        description = "Background opacity (0.0 - 1.0)";
      };

      backgroundBlurRadius = mkOption {
        type = types.int;
        default = 32;
        description = "Background blur radius in pixels";
      };

      unfocusedSplitOpacity = mkOption {
        type = types.float;
        default = 0.8;
        description = "Opacity of unfocused splits (0.0 - 1.0)";
      };

      boldIsBright = mkOption {
        type = types.bool;
        default = false;
        description = "Whether bold text uses bright colors (disable to keep Nord intact)";
      };

      windowColorspace = mkOption {
        type = types.str;
        default = "srgb";
        description = "Window colorspace (srgb or display-p3 for macOS wider gamut)";
      };

      macosTitlebarStyle = mkOption {
        type = types.enum ["native" "transparent" "tabs"];
        default = "transparent";
        description = "macOS titlebar style";
      };

      fontThickenStrength = mkOption {
        type = types.int;
        default = 70;
        description = "Font thicken strength (0-255, macOS only)";
      };

      unfocusedSplitFill = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Color to fill unfocused splits (null = no fill)";
      };
    };

    cursor = {
      style = mkOption {
        type = types.enum ["block" "bar" "underline"];
        default = "block";
        description = "Cursor style";
      };

      blink = mkOption {
        type = types.bool;
        default = true;
        description = "Enable cursor blinking";
      };
    };

    theme = {
      nordTheme = mkOption {
        type = types.bool;
        default = true;
        description = "Use elegant enhanced Nord color theme";
      };

      useBuiltinNord = mkOption {
        type = types.bool;
        default = false;
        description = "Use ghostty's built-in Nord theme instead of custom";
      };

      customColors = mkOption {
        type = types.attrs;
        default = {};
        description = "Custom color overrides";
        example = {
          background = "#1e1e1e";
          foreground = "#d4d4d4";
        };
      };
    };

    performance = {
      vsync = mkOption {
        type = types.bool;
        default = true;
        description = "Enable vsync for smoother rendering";
      };

      minimumContrast = mkOption {
        type = types.float;
        default = 1.1;
        description = "Minimum contrast for text";
      };
    };

    behavior = {
      confirmClose = mkOption {
        type = types.bool;
        default = false;
        description = "Confirm before closing terminal";
      };

      copyOnSelect = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically copy selected text to clipboard";
      };

      mouseHideWhileTyping = mkOption {
        type = types.bool;
        default = true;
        description = "Hide mouse cursor while typing";
      };

      scrollbackLimit = mkOption {
        type = types.int;
        default = 10000;
        description = "Number of lines in scrollback buffer";
      };

      mouseScrollMultiplier = mkOption {
        type = types.int;
        default = 2;
        description = "Mouse scroll speed multiplier";
      };

      gtkSingleInstance = mkOption {
        type = types.bool;
        default = true;
        description = "Use single instance for all windows (GTK)";
      };
    };

    shellIntegration = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable shell integration features";
      };

      features = mkOption {
        type = types.listOf types.str;
        default = ["cursor" "sudo" "title" "ssh-env" "ssh-terminfo"];
        description = "Shell integration features to enable";
      };
    };

    shaders = {
      enable = mkEnableOption "custom GLSL shaders";

      bloom = mkOption {
        type = types.bool;
        default = true;
        description = "Enable subtle bloom glow effect on bright text";
      };

      cursorGlow = mkOption {
        type = types.bool;
        default = false;
        description = "Enable soft frost-blue lightsaber halo around the cursor (works in all apps)";
      };

      cursorTrail = mkOption {
        type = types.bool;
        default = false;
        description = "Enable cursor trail effect when cursor moves (requires visible terminal cursor)";
      };

      promptSaber = mkOption {
        type = types.bool;
        default = false;
        description = "Enable lightsaber glow under the shell prompt line (auto-detects prompt vs TUI apps)";
      };

      filmGrain = mkOption {
        type = types.bool;
        default = true;
        description = "Enable subtle animated film grain for organic screen texture";
      };

      chromaticAberration = mkOption {
        type = types.bool;
        default = true;
        description = "Enable subtle edge chromatic aberration for perceived depth";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Crank all shader effects to exaggerated levels for visual verification";
      };

      animation = mkOption {
        type = types.bool;
        default = true;
        description = "Enable shader animation (set false for static effects only)";
      };

      custom = mkOption {
        type = types.listOf types.path;
        default = [];
        description = "Additional custom shader file paths to load";
      };
    };

    keybindings = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable curated keybinding defaults";
      };

      promptNavigation = mkOption {
        type = types.bool;
        default = true;
        description = "cmd+up/down to jump between shell prompts";
      };

      splitManagement = mkOption {
        type = types.bool;
        default = true;
        description = "ctrl+shift+arrows for split resize, cmd+shift+enter for zoom";
      };

      quickTerminal = mkOption {
        type = types.bool;
        default = true;
        description = "global:cmd+grave for quick terminal toggle";
      };

      custom = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional keybindings in 'keys=action' format";
        example = [ "ctrl+shift+c=copy_to_clipboard" "ctrl+shift+v=paste_from_clipboard" ];
      };
    };

    darwin = {
      useSourceBuild = mkOption {
        type = types.bool;
        default = false;
        description = "Use Ghostty built from source instead of prebuilt binary (requires Xcode)";
      };
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional ghostty settings";
      example = {
        "macos-option-as-alt" = true;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # Install ghostty package
    (mkIf pkgs.stdenv.isLinux {
      home.packages = [pkgs.ghostty];
    })
    (mkIf pkgs.stdenv.isDarwin {
      home.packages = [
        (if cfg.darwin.useSourceBuild
         then pkgs.ghostty
         else pkgs.ghostty-bin)
      ];
    })

    # Deploy shader files to ~/.config/ghostty/shaders/
    # In debug mode, swap in cranked-up values via builtins.replaceStrings.
    (mkIf cfg.shaders.enable {
      home.file = lib.listToAttrs (map (path: let
        name = builtins.baseNameOf (toString path);
        debugContent = debugOverrides.${name} or null;
        useDebug = cfg.shaders.debug && debugContent != null;
      in lib.nameValuePair
        ".config/ghostty/shaders/${name}"
        (if useDebug then { text = debugContent; } else { source = path; })
      ) builtinShaders);
    })

    # Configure ghostty with Nord theme on Linux using home-manager module
    (mkIf pkgs.stdenv.isLinux {
      programs.ghostty = {
        enable = true;
        settings = mkMerge [
        # Font configuration
        {
          font-family = cfg.font.family;
          font-size = cfg.font.size;
          font-thicken = cfg.font.thicken;
        }

        (mkIf (cfg.font.adjustCellHeight != 0) {
          adjust-cell-height = "${toString cfg.font.adjustCellHeight}%";
        })

        # Window configuration
        {
          window-padding-x = cfg.window.paddingX;
          window-padding-y = cfg.window.paddingY;
          window-padding-balance = true;
          window-padding-color = "background";
          window-decoration = cfg.window.decoration;
          window-theme = "auto";
          gtk-titlebar = cfg.window.gtkTitlebar;
          window-subtitle = "working-directory";
          gtk-tabs-location = "top";
        }

        # Appearance configuration
        {
          background-opacity = cfg.appearance.backgroundOpacity;
          background-blur-radius = cfg.appearance.backgroundBlurRadius;
          unfocused-split-opacity = cfg.appearance.unfocusedSplitOpacity;
          bold-is-bright = cfg.appearance.boldIsBright;
          window-colorspace = cfg.appearance.windowColorspace;
          macos-titlebar-style = cfg.appearance.macosTitlebarStyle;
          font-thicken-strength = cfg.appearance.fontThickenStrength;
        }

        (mkIf (cfg.appearance.unfocusedSplitFill != null) {
          unfocused-split-fill = cfg.appearance.unfocusedSplitFill;
        })

        # Use built-in Nord theme
        (mkIf (cfg.theme.nordTheme && cfg.theme.useBuiltinNord) {
          theme = "nord";
        })

        # Enhanced custom Nord color theme (if not using built-in)
        (mkIf (cfg.theme.nordTheme && !cfg.theme.useBuiltinNord) {
          # Background and foreground - elegant darker Nord
          background = cfg.theme.customColors.background or nord.nord0;
          foreground = cfg.theme.customColors.foreground or nord.nord6; # Brighter for elegance

          # Cursor - vibrant frost cyan with smooth contrast
          cursor-color = cfg.theme.customColors.cursor-color or nord.nord8;
          cursor-text = cfg.theme.customColors.cursor-text or nord.nord0;
          cursor-style = cfg.cursor.style;
          cursor-style-blink = cfg.cursor.blink;

          # Selection - subtle highlighting with better contrast
          selection-background = cfg.theme.customColors.selection-background or nord.nord3; # Lighter for better visibility
          selection-foreground = cfg.theme.customColors.selection-foreground or nord.nord6;

          # Enhanced Nord palette - carefully balanced for beauty
          palette = [
            # Normal colors
            "0=${nord.nord1}"   # black (darker than bg for depth)
            "1=${nord.nord11}"  # red (aurora red - warm accent)
            "2=${nord.nord14}"  # green (aurora green - success)
            "3=${nord.nord13}"  # yellow (aurora yellow - warnings)
            "4=${nord.nord10}"  # blue (frost blue - deeper than cyan)
            "5=${nord.nord15}"  # magenta (aurora purple - elegance)
            "6=${nord.nord8}"   # cyan (frost cyan - primary accent)
            "7=${nord.nord5}"   # white (snow storm)

            # Bright colors - enhanced for better visibility
            "8=${nord.nord3}"   # bright black (gray for dim text)
            "9=${nord.nord11}"  # bright red (consistent with normal)
            "10=${nord.nord14}" # bright green (vibrant)
            "11=${nord.nord13}" # bright yellow (vibrant warnings)
            "12=${nord.nord9}"  # bright blue (lighter frost)
            "13=${nord.nord15}" # bright magenta (purple accent)
            "14=${nord.nord7}"  # bright cyan (lightest frost - highlights)
            "15=${nord.nord6}"  # bright white (pure snow - emphasis)
          ];
        })

        # Shader settings
        (mkIf cfg.shaders.enable ({
          custom-shader-animation = cfg.shaders.animation;
        } // lib.optionalAttrs (allShaderPaths != []) {
          custom-shader = map (path:
            "${config.home.homeDirectory}/.config/ghostty/shaders/${builtins.baseNameOf (toString path)}"
          ) allShaderPaths;
        }))

        # Keybinding settings
        (mkIf cfg.keybindings.enable ({
          macos-option-as-alt = true;
        } // lib.optionalAttrs (allKeybinds != []) {
          keybind = allKeybinds;
        }))

        # Performance settings
        {
          window-vsync = cfg.performance.vsync;
          minimum-contrast = cfg.performance.minimumContrast;
        }

        # Shell integration
        (mkIf cfg.shellIntegration.enable {
          shell-integration = "detect";
          shell-integration-features = concatStringsSep "," cfg.shellIntegration.features;
        })

        # Behavior settings
        {
          confirm-close-surface = cfg.behavior.confirmClose;
          clipboard-read = "allow";
          clipboard-write = "allow";
          clipboard-trim-trailing-spaces = true;
          copy-on-select = cfg.behavior.copyOnSelect;
          mouse-hide-while-typing = cfg.behavior.mouseHideWhileTyping;
          mouse-shift-capture = true;
          mouse-scroll-multiplier = cfg.behavior.mouseScrollMultiplier;
          scrollback-limit = cfg.behavior.scrollbackLimit;
          link-url = true;
          gtk-single-instance = cfg.behavior.gtkSingleInstance;
          window-save-state = "default";
          resize-overlay = "never";
        }

        # Extra user-defined settings
        cfg.extraSettings
      ];
    };
    })

    # On macOS, write config file directly (user installs ghostty manually)
    (mkIf pkgs.stdenv.isDarwin {
      home.file.".config/ghostty/config".text = let
        # Build settings as key-value pairs
        fontSettings = ''
          font-family = ${cfg.font.family}
          font-size = ${toString cfg.font.size}
          font-thicken = ${if cfg.font.thicken then "true" else "false"}
        '' + optionalString (cfg.font.adjustCellHeight != 0) ''
          adjust-cell-height = ${toString cfg.font.adjustCellHeight}%
        '';

        windowSettings = ''
          window-padding-x = ${toString cfg.window.paddingX}
          window-padding-y = ${toString cfg.window.paddingY}
          window-padding-balance = true
          window-padding-color = background
          window-decoration = ${if cfg.window.decoration then "true" else "false"}
          window-theme = auto
          window-colorspace = ${cfg.appearance.windowColorspace}
        '';

        appearanceSettings = ''
          background-opacity = ${toString cfg.appearance.backgroundOpacity}
          background-blur-radius = ${toString cfg.appearance.backgroundBlurRadius}
          unfocused-split-opacity = ${toString cfg.appearance.unfocusedSplitOpacity}
          bold-is-bright = ${if cfg.appearance.boldIsBright then "true" else "false"}
          macos-titlebar-style = ${cfg.appearance.macosTitlebarStyle}
          font-thicken-strength = ${toString cfg.appearance.fontThickenStrength}
        '' + optionalString (cfg.appearance.unfocusedSplitFill != null) ''
          unfocused-split-fill = ${cfg.appearance.unfocusedSplitFill}
        '';

        nordThemeSettings = if cfg.theme.nordTheme && cfg.theme.useBuiltinNord then ''
          theme = nord
        '' else if cfg.theme.nordTheme then ''
          background = ${cfg.theme.customColors.background or nord.nord0}
          foreground = ${cfg.theme.customColors.foreground or nord.nord6}
          cursor-color = ${cfg.theme.customColors.cursor-color or nord.nord8}
          cursor-text = ${cfg.theme.customColors.cursor-text or nord.nord0}
          selection-background = ${cfg.theme.customColors.selection-background or nord.nord3}
          selection-foreground = ${cfg.theme.customColors.selection-foreground or nord.nord6}
          palette = 0=${nord.nord1}
          palette = 1=${nord.nord11}
          palette = 2=${nord.nord14}
          palette = 3=${nord.nord13}
          palette = 4=${nord.nord10}
          palette = 5=${nord.nord15}
          palette = 6=${nord.nord8}
          palette = 7=${nord.nord5}
          palette = 8=${nord.nord3}
          palette = 9=${nord.nord11}
          palette = 10=${nord.nord14}
          palette = 11=${nord.nord13}
          palette = 12=${nord.nord9}
          palette = 13=${nord.nord15}
          palette = 14=${nord.nord7}
          palette = 15=${nord.nord6}
        '' else "";

        cursorSettings = ''
          cursor-style = ${cfg.cursor.style}
          cursor-style-blink = ${if cfg.cursor.blink then "true" else "false"}
        '';

        performanceSettings = ''
          window-vsync = ${if cfg.performance.vsync then "true" else "false"}
          minimum-contrast = ${toString cfg.performance.minimumContrast}
        '';

        behaviorSettings = ''
          confirm-close-surface = ${if cfg.behavior.confirmClose then "true" else "false"}
          clipboard-read = allow
          clipboard-write = allow
          clipboard-trim-trailing-spaces = true
          copy-on-select = ${if cfg.behavior.copyOnSelect then "true" else "false"}
          mouse-hide-while-typing = ${if cfg.behavior.mouseHideWhileTyping then "true" else "false"}
          mouse-shift-capture = true
          mouse-scroll-multiplier = ${toString cfg.behavior.mouseScrollMultiplier}
          scrollback-limit = ${toString cfg.behavior.scrollbackLimit}
          link-url = true
          window-save-state = default
          resize-overlay = never
        '';

        shellIntegrationSettings = if cfg.shellIntegration.enable then ''
          shell-integration = detect
          shell-integration-features = ${concatStringsSep "," cfg.shellIntegration.features}
        '' else "";

        shaderSettings = optionalString cfg.shaders.enable (
          "custom-shader-animation = ${if cfg.shaders.animation then "true" else "false"}\n"
          + concatMapStringsSep "\n" (path:
            "custom-shader = ${config.home.homeDirectory}/.config/ghostty/shaders/${builtins.baseNameOf (toString path)}"
          ) allShaderPaths
        );

        keybindSettings = optionalString cfg.keybindings.enable (
          "macos-option-as-alt = true\n"
          + concatMapStringsSep "\n" (kb: "keybind = ${kb}") allKeybinds
        );

        extraSettingsText = concatStringsSep "\n" (
          mapAttrsToList (k: v:
            if builtins.isBool v then "${k} = ${if v then "true" else "false"}"
            else "${k} = ${toString v}"
          ) cfg.extraSettings
        );

      in ''
        # Ghostty Configuration - Nord Theme
        # Managed by Nix (blackmatter.components.ghostty)

        ${fontSettings}

        ${windowSettings}

        ${appearanceSettings}

        ${nordThemeSettings}

        ${cursorSettings}

        ${performanceSettings}

        ${behaviorSettings}

        ${shellIntegrationSettings}

        ${shaderSettings}

        ${keybindSettings}

        ${extraSettingsText}
      '';
    })
  ]);
}
