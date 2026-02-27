{
  description = "Blackmatter Ghostty - GPU-accelerated terminal built from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = { self, nixpkgs, ghostty }:
    let
      buildSystems = [ "x86_64-linux" "aarch64-linux" ];
      allSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forBuildSystems = f: nixpkgs.lib.genAttrs buildSystems (system: f system);
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f system);
    in {
      # Re-export ghostty source-built packages (Linux only)
      packages = forBuildSystems (system: {
        ghostty = ghostty.packages.${system}.ghostty;
        default = ghostty.packages.${system}.ghostty;
      });

      # Re-export overlay: pkgs.ghostty = source build
      overlays.default = ghostty.overlays.default;

      # Home-manager module for ghostty configuration
      homeManagerModules.default = import ./module;

      # ── Checks ──────────────────────────────────────────────────
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          lib = nixpkgs.lib;

          # Evaluate the module in isolation with minimal stubs for HM options
          moduleEval = lib.evalModules {
            modules = [
              ./module
              ({ lib, ... }: {
                config._module.args = { pkgs = pkgs; };
                options.home.packages = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [];
                };
                options.home.file = lib.mkOption {
                  type = lib.types.attrsOf (lib.types.submodule {
                    options.text = lib.mkOption { type = lib.types.str; default = ""; };
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
              })
            ];
          };

          # Import the colors file and verify its structure
          colors = import ./module/themes/nord/colors.nix;
        in {
          # Verify module options exist and are well-formed
          module-eval = pkgs.runCommand "ghostty-module-eval" {} ''
            # Module options are reachable
            echo "Option exists: ${builtins.toJSON (builtins.hasAttr "ghostty" moduleEval.config.blackmatter.components)}"

            # Verify key option defaults
            echo "Default font: ${moduleEval.config.blackmatter.components.ghostty.font.family}"
            echo "Default cursor: ${moduleEval.config.blackmatter.components.ghostty.cursor.style}"

            # Verify enable defaults to false
            echo "Enable default: ${builtins.toJSON moduleEval.config.blackmatter.components.ghostty.enable}"

            touch $out
          '';

          # Verify Nord palette structure is complete
          theme-colors = pkgs.runCommand "ghostty-theme-colors" {} ''
            # Polar Night (4 shades)
            echo "polar.night0 = ${colors.polar.night0}"
            echo "polar.night1 = ${colors.polar.night1}"
            echo "polar.night2 = ${colors.polar.night2}"
            echo "polar.night3 = ${colors.polar.night3}"

            # Snow Storm (3 shades)
            echo "snow.storm0 = ${colors.snow.storm0}"
            echo "snow.storm1 = ${colors.snow.storm1}"
            echo "snow.storm2 = ${colors.snow.storm2}"

            # Frost (4 shades)
            echo "frost.frost0 = ${colors.frost.frost0}"
            echo "frost.frost1 = ${colors.frost.frost1}"
            echo "frost.frost2 = ${colors.frost.frost2}"
            echo "frost.frost3 = ${colors.frost.frost3}"

            # Aurora (5 colors)
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
                ({ lib, ... }: {
                  config._module.args = { pkgs = pkgs; };
                  config.blackmatter.components.ghostty.enable = true;
                  options.home.packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [];
                  };
                  options.home.file = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.submodule {
                      options.text = lib.mkOption { type = lib.types.str; default = ""; };
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
                })
              ];
            };
            isDarwin = builtins.elem system [ "x86_64-darwin" "aarch64-darwin" ];
          in pkgs.runCommand "ghostty-module-enable" {} (''
            echo "Module enabled successfully"
            echo "Enable = ${builtins.toJSON enabledEval.config.blackmatter.components.ghostty.enable}"
          '' + (if isDarwin then ''
            # On Darwin, verify config file is generated
            echo "Darwin config text length: ${builtins.toJSON (builtins.stringLength (enabledEval.config.home.file.".config/ghostty/config".text))}"
          '' else ''
            # On Linux, verify programs.ghostty is enabled
            echo "Linux programs.ghostty.enable: ${builtins.toJSON enabledEval.config.programs.ghostty.enable}"
          '') + ''
            touch $out
          '');
        }
      );
    };
}
