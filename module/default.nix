# module/default.nix
# Ghostty terminal emulator — GPU-accelerated, Nord-themed, shader-enhanced.
#
# Graphical effects are managed by extracted sub-modules in graphics/:
#   shader-pipeline.nix — shader ordering, layer classification, debug overrides
#   theme.nix           — Nord palette mapping and color generation
#   settings.nix        — unified graphical settings builder
#   serialize.nix       — attrset → Ghostty config text serializer
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.blackmatter.components.ghostty;

  # ── Graphics sub-modules ────────────────────────────────────────
  graphics       = import ./graphics { inherit lib; };
  shaderPipeline = graphics.shaderPipeline;
  serialize      = import ./graphics/serialize.nix { inherit lib; };

  # ── Shader pipeline (ordered, filtered by cfg toggles) ──────────
  allShaderPaths = (shaderPipeline.mkPipeline cfg) ++ cfg.shaders.custom;

  # ── Keybinding composition ──────────────────────────────────────
  promptNavBinds = optionals cfg.keybindings.promptNavigation [
    "cmd+up=jump_to_prompt:-1"
    "cmd+down=jump_to_prompt:1"
  ];

  splitBinds = optionals cfg.keybindings.splitManagement [
    "ctrl+shift+up=resize_split:up,10"
    "ctrl+shift+down=resize_split:down,10"
    "ctrl+shift+left=resize_split:left,10"
    "ctrl+shift+right=resize_split:right,10"
    "cmd+shift+enter=toggle_split_zoom"
    "cmd+shift+e=equalize_splits"
  ];

  quickTermBinds = optionals cfg.keybindings.quickTerminal [
    "global:cmd+grave_accent=toggle_quick_terminal"
  ];

  allKeybinds = promptNavBinds ++ splitBinds ++ quickTermBinds ++ cfg.keybindings.custom;

  # ── Unified settings attrset ────────────────────────────────────
  # Used by both Linux (programs.ghostty.settings) and Darwin (text config).
  # Composed from graphics + behavior + shell + shaders + keybindings.
  fullSettings = mkMerge [
    # Graphical settings (font, window, appearance, cursor, theme, perf)
    (graphics.settings.mkGraphicsSettings cfg)

    # Linux-only window settings
    (mkIf pkgs.stdenv.isLinux {
      gtk-titlebar = cfg.window.gtkTitlebar;
      gtk-tabs-location = "top";
    })

    # Shell integration
    (mkIf cfg.shellIntegration.enable {
      shell-integration = "detect";
      shell-integration-features = concatStringsSep "," cfg.shellIntegration.features;
    })

    # Title (override upstream ghost emoji default)
    {
      title = "❄";
    }

    # Behavior
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
      window-save-state = "default";
      resize-overlay = "never";
    }

    (mkIf pkgs.stdenv.isLinux {
      gtk-single-instance = cfg.behavior.gtkSingleInstance;
    })

    # Shaders
    (mkIf cfg.shaders.enable
      (shaderPipeline.mkShaderSettings {
        inherit cfg;
        homeDir = config.home.homeDirectory;
      }))

    # Keybindings
    (mkIf cfg.keybindings.enable ({
      macos-option-as-alt = true;
    } // optionalAttrs (allKeybinds != []) {
      keybind = allKeybinds;
    }))

    # Extra user-defined settings
    cfg.extraSettings
  ];

in {
  # ══════════════════════════════════════════════════════════════════
  # OPTIONS
  # ══════════════════════════════════════════════════════════════════
  options.blackmatter.components.ghostty = {
    enable = mkEnableOption "Ghostty terminal emulator";

    # ── Font ──────────────────────────────────────────────────────
    font = {
      family = mkOption {
        type = types.str;
        default = "JetBrains Mono";
        description = "Font family for terminal";
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

    # ── Window ────────────────────────────────────────────────────
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

    # ── Appearance ────────────────────────────────────────────────
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

    # ── Cursor ────────────────────────────────────────────────────
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

    # ── Theme ─────────────────────────────────────────────────────
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
      };
    };

    # ── Performance ───────────────────────────────────────────────
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

    # ── Behavior ──────────────────────────────────────────────────
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

    # ── Shell Integration ─────────────────────────────────────────
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

    # ── Shaders ───────────────────────────────────────────────────
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
        description = "Enable soft frost-blue lightsaber halo around the cursor";
      };
      cursorTrail = mkOption {
        type = types.bool;
        default = false;
        description = "Enable cursor trail effect when cursor moves";
      };
      promptSaber = mkOption {
        type = types.bool;
        default = false;
        description = "Enable lightsaber glow under the shell prompt line";
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
      spotlight = mkOption {
        type = types.bool;
        default = false;
        description = "Enable soft cursor-centered spotlight that dims distant areas";
      };
      screenCurvature = mkOption {
        type = types.bool;
        default = false;
        description = "Enable subtle barrel distortion for CRT-like display depth";
      };
      backgroundPulse = mkOption {
        type = types.bool;
        default = false;
        description = "Enable ultra-slow Nord frost color breathing on dark background areas";
      };
      frostHaze = mkOption {
        type = types.bool;
        default = false;
        description = "Enable atmospheric frost condensation veil at screen edges";
      };
      sonicBoom = mkOption {
        type = types.bool;
        default = false;
        description = "Enable expanding ripple ring when cursor arrives at a new position";
      };
      stardust = mkOption {
        type = types.bool;
        default = false;
        description = "Enable barely perceptible twinkling frost particles on dark areas";
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

    # ── Keybindings ───────────────────────────────────────────────
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
      };
    };

    # ── Darwin ────────────────────────────────────────────────────
    darwin = {
      useSourceBuild = mkOption {
        type = types.bool;
        default = false;
        description = "Use Ghostty built from source instead of prebuilt binary (requires Xcode)";
      };
    };

    # ── Extra ─────────────────────────────────────────────────────
    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional ghostty settings";
    };

    # ── Workspaces ────────────────────────────────────────────────
    workspaces = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          displayName = mkOption {
            type = types.str;
            default = name;
            description = "Display name shown in title bar.";
          };
          theme = {
            cursorColor = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Cursor color override (hex).";
            };
            selectionBackground = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Selection background color override (hex).";
            };
            background = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Background color override for subtle ambient tint (hex).";
            };
          };
          extraConfig = mkOption {
            type = types.lines;
            default = "";
            description = "Extra Ghostty config lines for this workspace.";
          };
        };
      }));
      default = {};
      description = "Workspace-specific Ghostty configurations.";
    };
  };

  # ══════════════════════════════════════════════════════════════════
  # CONFIG
  # ══════════════════════════════════════════════════════════════════
  config = mkIf cfg.enable (mkMerge [
    # ── Package installation ──────────────────────────────────────
    (mkIf pkgs.stdenv.isLinux {
      home.packages = [pkgs.ghostty];
    })
    (mkIf pkgs.stdenv.isDarwin (let
      ghosttyPkg =
        if cfg.darwin.useSourceBuild then pkgs.ghostty else pkgs.ghostty-bin;
      currentAppPath = "${ghosttyPkg}/Applications/Ghostty.app";
    in {
      home.packages = [ ghosttyPkg ];

      # Every blackmatter-ghostty bump produces a new Nix store path.
      # LaunchServices never evicts prior registrations, so macOS can
      # resolve "Ghostty" to a stale (possibly garbage-collected or
      # signature-broken) bundle — which, after TCC binding, surfaces as
      # "Ghostty.app is damaged and can't be opened". Prune every
      # Ghostty.app registration that isn't the currently-active store
      # path, then re-register the current one.
      home.activation.ghosttyLaunchServices =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          lsregister="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
          current=${lib.escapeShellArg currentAppPath}
          hmLink="$HOME/Applications/Home Manager Apps/Ghostty.app"

          if [ ! -x "$lsregister" ] || [ ! -d "$current" ]; then
            exit 0
          fi

          stale=$(
            "$lsregister" -dump 2>/dev/null \
              | ${pkgs.gawk}/bin/awk '
                  /^path:[[:space:]]+\// && /\/Applications\/Ghostty\.app[[:space:]]/ {
                    sub(/^path:[[:space:]]+/, "");
                    sub(/[[:space:]]+\(0x[0-9a-f]+\)$/, "");
                    print
                  }
                ' \
              | sort -u \
              | grep -vxF "$current" || true
          )

          pruned=0
          if [ -n "$stale" ]; then
            while IFS= read -r p; do
              [ -z "$p" ] && continue
              if "$lsregister" -u "$p" >/dev/null 2>&1; then
                pruned=$((pruned + 1))
              fi
            done <<< "$stale"
          fi

          "$lsregister" -f "$current" >/dev/null 2>&1 || true
          if [ -L "$hmLink" ] || [ -d "$hmLink" ]; then
            "$lsregister" -f "$hmLink" >/dev/null 2>&1 || true
          fi

          echo "ghostty: LaunchServices pruned $pruned stale registration(s), re-registered $current"
        '';
    }))

    # ── Shader file deployment ────────────────────────────────────
    (mkIf cfg.shaders.enable {
      home.file = shaderPipeline.mkShaderFiles cfg;
    })

    # ── Linux: use programs.ghostty module ────────────────────────
    (mkIf pkgs.stdenv.isLinux {
      programs.ghostty = {
        enable = true;
        settings = fullSettings;
      };
    })

    # ── Darwin: write config text directly ────────────────────────
    (mkIf pkgs.stdenv.isDarwin {
      home.file.".config/ghostty/config".text = let
        # Resolve the merged settings to a plain attrset.
        # mkMerge produces a module option value; we need to evaluate it
        # in the programs.ghostty context or flatten manually.
        # For Darwin we build the same attrset and serialize it.
        resolved = lib.foldl lib.recursiveUpdate {} [
          # Font
          {
            font-family = cfg.font.family;
            font-size = cfg.font.size;
            font-thicken = cfg.font.thicken;
          }
          (optionalAttrs (cfg.font.adjustCellHeight != 0) {
            adjust-cell-height = "${toString cfg.font.adjustCellHeight}%";
          })
          # Window
          {
            window-padding-x = cfg.window.paddingX;
            window-padding-y = cfg.window.paddingY;
            window-padding-balance = true;
            window-padding-color = "background";
            window-decoration = cfg.window.decoration;
            window-theme = "auto";
            window-colorspace = cfg.appearance.windowColorspace;
          }
          # Appearance
          {
            background-opacity = cfg.appearance.backgroundOpacity;
            background-blur-radius = cfg.appearance.backgroundBlurRadius;
            unfocused-split-opacity = cfg.appearance.unfocusedSplitOpacity;
            bold-is-bright = cfg.appearance.boldIsBright;
            macos-titlebar-style = cfg.appearance.macosTitlebarStyle;
            font-thicken-strength = cfg.appearance.fontThickenStrength;
          }
          (optionalAttrs (cfg.appearance.unfocusedSplitFill != null) {
            unfocused-split-fill = cfg.appearance.unfocusedSplitFill;
          })
          # Theme
          (graphics.theme.mkThemeSettings cfg)
          # Cursor
          {
            cursor-style = cfg.cursor.style;
            cursor-style-blink = cfg.cursor.blink;
          }
          # Performance
          {
            window-vsync = cfg.performance.vsync;
            minimum-contrast = cfg.performance.minimumContrast;
          }
          # Title (override upstream ghost emoji default)
          {
            title = "❄";
          }
          # Behavior
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
            window-save-state = "default";
            resize-overlay = "never";
          }
          # Shell integration
          (optionalAttrs cfg.shellIntegration.enable {
            shell-integration = "detect";
            shell-integration-features = concatStringsSep "," cfg.shellIntegration.features;
          })
          # Shaders
          (optionalAttrs cfg.shaders.enable
            (shaderPipeline.mkShaderSettings {
              inherit cfg;
              homeDir = config.home.homeDirectory;
            }))
          # Keybindings
          (optionalAttrs cfg.keybindings.enable ({
            macos-option-as-alt = true;
          } // optionalAttrs (allKeybinds != []) {
            keybind = allKeybinds;
          }))
          # Extra
          cfg.extraSettings
        ];
      in ''
        # Ghostty Configuration — Nord Theme
        # Managed by Nix (blackmatter.components.ghostty)

        ${serialize.settingsToText resolved}
      '';
    })

    # ── Workspace configs and wrapper scripts ─────────────────────
    (mkIf (cfg.workspaces != {}) (let
      baseConfigPath = "${config.home.homeDirectory}/.config/ghostty/config";

      ghosttyPkg =
        if pkgs.stdenv.isDarwin then
          (if cfg.darwin.useSourceBuild then pkgs.ghostty else pkgs.ghostty-bin)
        else
          pkgs.ghostty;
      ghosttyBin =
        if pkgs.stdenv.isDarwin && cfg.darwin.useSourceBuild then
          "${ghosttyPkg}/Applications/Ghostty.app/Contents/MacOS/ghostty"
        else
          "${ghosttyPkg}/bin/ghostty";

      wsJson = builtins.toJSON {
        baseConfigPath = baseConfigPath;
        ghosttyBin = ghosttyBin;
        bundleIdPrefix = "io.pleme";
        workspaces = mapAttrsToList (name: ws: {
          inherit name;
          displayName = ws.displayName;
          theme = {
            cursorColor = ws.theme.cursorColor;
            selectionBackground = ws.theme.selectionBackground;
            background = ws.theme.background;
          };
          extraConfig = ws.extraConfig;
        }) cfg.workspaces;
      };

      workspaceArtifacts = pkgs.runCommand "ghostty-workspaces" {
        nativeBuildInputs = [ pkgs.workspace-config ];
        passAsFile = [ "wsJson" ];
        inherit wsJson;
      } ''
        mkdir -p $out/{configs,wrappers,Applications}
        workspace-config generate-all \
          --input "$wsJsonPath" \
          --config-dir $out/configs \
          --wrapper-dir $out/wrappers \
          --app-dir $out/Applications
        chmod +x $out/wrappers/*
      '';

      workspaceConfigs = mapAttrs' (name: _ws:
        nameValuePair ".config/ghostty/config-${name}" {
          source = "${workspaceArtifacts}/configs/config-${name}";
        }
      ) cfg.workspaces;

      workspaceRuntimeConfig = {
        ".config/workspace-config/wrappers.d/ghostty.yaml" = {
          source = "${workspaceArtifacts}/wrappers/wrappers.yaml";
        };
      };

      workspaceWrapperPkg = pkgs.runCommand "ghostty-workspace-wrappers" {} ''
        mkdir -p $out/bin
        ${concatStringsSep "\n" (mapAttrsToList (name: _ws:
          "ln -s ${pkgs.workspace-config}/bin/workspace-config $out/bin/ghostty-${name}"
        ) cfg.workspaces)}
      '';

      workspaceAppPkg = pkgs.runCommand "ghostty-workspace-apps" {} ''
        ${concatStringsSep "\n" (mapAttrsToList (name: ws: ''
          mkdir -p "$out/Applications/Ghostty ${ws.displayName}.app/Contents/MacOS"
          ln -s ${pkgs.workspace-config}/bin/workspace-config \
            "$out/Applications/Ghostty ${ws.displayName}.app/Contents/MacOS/ghostty-${name}"
          cp "${workspaceArtifacts}/Applications/Ghostty ${ws.displayName}.app/Contents/Info.plist" \
            "$out/Applications/Ghostty ${ws.displayName}.app/Contents/Info.plist"
        '') cfg.workspaces)}
      '';

      workspaceApps = optionals pkgs.stdenv.isDarwin [workspaceAppPkg];
    in {
      home.file = workspaceConfigs // workspaceRuntimeConfig;
      home.packages = [workspaceWrapperPkg] ++ workspaceApps;
    }))
  ]);
}
