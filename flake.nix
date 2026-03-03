{
  description = "Blackmatter Ghostty - GPU-accelerated terminal built from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    ghostty.url = "github:ghostty-org/ghostty";
    substrate = {
      url = "github:pleme-io/substrate";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blackmatter-macos = {
      url = "github:pleme-io/blackmatter-macos";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
      inputs.blackmatter-zig.follows = "blackmatter-zig";
    };
    blackmatter-zig = {
      url = "github:pleme-io/blackmatter-zig";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
    };
    dev-tools = {
      url = "github:pleme-io/dev-tools";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
    };
  };

  outputs = { self, nixpkgs, ghostty, substrate, blackmatter-macos, blackmatter-zig, dev-tools }:
    let
      lib = nixpkgs.lib;

      linuxSystems = [ "x86_64-linux" "aarch64-linux" ];
      darwinSystems = [ "x86_64-darwin" "aarch64-darwin" ];
      allSystems = linuxSystems ++ darwinSystems;

      isDarwin = system: builtins.elem system darwinSystems;

      forAllSystems = f: lib.genAttrs allSystems (system: f system);
      forLinux = f: lib.genAttrs linuxSystems (system: f system);
      forDarwin = f: lib.genAttrs darwinSystems (system: f system);

      # Darwin pkgs with Zig + Swift overlays for source builds
      darwinPkgs = system: import nixpkgs {
        inherit system;
        overlays = [
          blackmatter-macos.overlays.default
          blackmatter-zig.overlays.default
        ];
      };

      # Build the Darwin source package for a given system
      mkDarwinGhostty = system: let
        pkgs = darwinPkgs system;
        nix-macos = dev-tools.packages.${system}.nix-macos;
      in import ./pkgs/ghostty-darwin.nix {
        inherit pkgs lib nix-macos;
        mkZigSwiftApp = pkgs.mkZigSwiftApp;
        ghosttySrc = ghostty;
      };

      # Shared HM module stubs for check evaluation
      mkHmStubs = pkgs: { lib, ... }: {
        config._module.args = { inherit pkgs; };
        options.home.packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        options.home.homeDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/test";
        };
        options.home.file = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options.text = lib.mkOption { type = lib.types.str; default = ""; };
            options.source = lib.mkOption { type = lib.types.path; default = ./.; };
          });
          default = {};
        };
        options.programs.ghostty = lib.mkOption {
          type = lib.types.submodule {
            options.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.settings = lib.mkOption { type = lib.types.anything; default = {}; };
          };
          default = {};
        };
      };
    in {
      # ── Packages ─────────────────────────────────────────────────
      packages =
        # Linux: re-export upstream source builds
        (forLinux (system: {
          ghostty = ghostty.packages.${system}.ghostty;
          default = ghostty.packages.${system}.ghostty;
        }))
        //
        # Darwin: source build via mkZigSwiftApp
        (forDarwin (system: let
          ghosttyDarwin = mkDarwinGhostty system;
        in {
          ghostty = ghosttyDarwin;
          ghostty-source = ghosttyDarwin;
          default = ghosttyDarwin;
        }));

      # ── Overlay ──────────────────────────────────────────────────
      overlays.default = final: prev:
        if prev.stdenv.isDarwin then {
          ghostty = self.packages.${prev.stdenv.hostPlatform.system}.ghostty;
        } else
          ghostty.overlays.default final prev;

      # ── Home-manager module ──────────────────────────────────────
      homeManagerModules.default = import ./module;

      # ── Dev shells (Darwin — for iterating on the build) ─────────
      devShells = forDarwin (system: let
        pkgs = darwinPkgs system;
      in {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.zigToolchain
            pkgs.swiftToolchain
          ];
          shellHook = ''
            unset SDKROOT
            unset DEVELOPER_DIR
            echo "Ghostty dev shell — Zig + Swift toolchains available"
            echo "  zig version: $(zig version)"
            echo "  swift --version: $(swift --version 2>&1 | head -1)"
          '';
        };
      });

      # ── Checks ──────────────────────────────────────────────────
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };

          moduleEval = lib.evalModules {
            modules = [
              ./module
              (mkHmStubs pkgs)
            ];
          };

          colors = import ./module/themes/nord/colors.nix;
        in {
          # Verify module options exist and are well-formed
          module-eval = pkgs.runCommand "ghostty-module-eval" {} ''
            echo "Option exists: ${builtins.toJSON (builtins.hasAttr "ghostty" moduleEval.config.blackmatter.components)}"
            echo "Default font: ${moduleEval.config.blackmatter.components.ghostty.font.family}"
            echo "Default cursor: ${moduleEval.config.blackmatter.components.ghostty.cursor.style}"
            echo "Enable default: ${builtins.toJSON moduleEval.config.blackmatter.components.ghostty.enable}"
            touch $out
          '';

          # Verify Nord palette structure is complete
          theme-colors = pkgs.runCommand "ghostty-theme-colors" {} ''
            echo "polar.night0 = ${colors.polar.night0}"
            echo "polar.night1 = ${colors.polar.night1}"
            echo "polar.night2 = ${colors.polar.night2}"
            echo "polar.night3 = ${colors.polar.night3}"
            echo "snow.storm0 = ${colors.snow.storm0}"
            echo "snow.storm1 = ${colors.snow.storm1}"
            echo "snow.storm2 = ${colors.snow.storm2}"
            echo "frost.frost0 = ${colors.frost.frost0}"
            echo "frost.frost1 = ${colors.frost.frost1}"
            echo "frost.frost2 = ${colors.frost.frost2}"
            echo "frost.frost3 = ${colors.frost.frost3}"
            echo "aurora.red = ${colors.aurora.red}"
            echo "aurora.orange = ${colors.aurora.orange}"
            echo "aurora.yellow = ${colors.aurora.yellow}"
            echo "aurora.green = ${colors.aurora.green}"
            echo "aurora.purple = ${colors.aurora.purple}"
            touch $out
          '';

          # Verify module enables correctly (with enable = true)
          module-enable = let
            enabledEval = lib.evalModules {
              modules = [
                ./module
                (mkHmStubs pkgs)
                ({ ... }: {
                  config.blackmatter.components.ghostty.enable = true;
                })
              ];
            };
            darwinSystem = isDarwin system;
          in pkgs.runCommand "ghostty-module-enable" {} (''
            echo "Module enabled successfully"
            echo "Enable = ${builtins.toJSON enabledEval.config.blackmatter.components.ghostty.enable}"
          '' + (if darwinSystem then ''
            echo "Darwin config text length: ${builtins.toJSON (builtins.stringLength (enabledEval.config.home.file.".config/ghostty/config".text))}"
          '' else ''
            echo "Linux programs.ghostty.enable: ${builtins.toJSON enabledEval.config.programs.ghostty.enable}"
          '') + ''
            touch $out
          '');

          # Verify shader-enabled module evaluates correctly
          module-shaders = let
            shaderEval = lib.evalModules {
              modules = [
                ./module
                (mkHmStubs pkgs)
                ({ ... }: {
                  config.blackmatter.components.ghostty = {
                    enable = true;
                    shaders.enable = true;
                  };
                })
              ];
            };
          in pkgs.runCommand "ghostty-module-shaders" {} ''
            echo "Shaders enabled: ${builtins.toJSON shaderEval.config.blackmatter.components.ghostty.shaders.enable}"
            echo "Bloom: ${builtins.toJSON shaderEval.config.blackmatter.components.ghostty.shaders.bloom}"
            echo "Cursor trail: ${builtins.toJSON shaderEval.config.blackmatter.components.ghostty.shaders.cursorTrail}"
            echo "Animation: ${builtins.toJSON shaderEval.config.blackmatter.components.ghostty.shaders.animation}"
            touch $out
          '';

          # Verify keybindings module evaluates correctly
          module-keybindings = let
            kbEval = lib.evalModules {
              modules = [
                ./module
                (mkHmStubs pkgs)
                ({ ... }: {
                  config.blackmatter.components.ghostty = {
                    enable = true;
                    keybindings.enable = true;
                  };
                })
              ];
            };
          in pkgs.runCommand "ghostty-module-keybindings" {} ''
            echo "Keybindings enabled: ${builtins.toJSON kbEval.config.blackmatter.components.ghostty.keybindings.enable}"
            echo "Prompt nav: ${builtins.toJSON kbEval.config.blackmatter.components.ghostty.keybindings.promptNavigation}"
            echo "Split management: ${builtins.toJSON kbEval.config.blackmatter.components.ghostty.keybindings.splitManagement}"
            echo "Quick terminal: ${builtins.toJSON kbEval.config.blackmatter.components.ghostty.keybindings.quickTerminal}"
            touch $out
          '';

          # Verify the useSourceBuild option evaluates on Darwin
        } // lib.optionalAttrs (isDarwin system) {
          module-source-option = let
            sourceEval = lib.evalModules {
              modules = [
                ./module
                (mkHmStubs pkgs)
                ({ ... }: {
                  config.blackmatter.components.ghostty = {
                    enable = true;
                    darwin.useSourceBuild = true;
                  };
                })
              ];
            };
          in pkgs.runCommand "ghostty-module-source-option" {} ''
            echo "useSourceBuild = ${builtins.toJSON sourceEval.config.blackmatter.components.ghostty.darwin.useSourceBuild}"
            echo "Config text length: ${builtins.toJSON (builtins.stringLength (sourceEval.config.home.file.".config/ghostty/config".text))}"
            touch $out
          '';
        }
      );
    };
}
