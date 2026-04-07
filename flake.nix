{
  description = "Blackmatter Ghostty - GPU-accelerated terminal built from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Pin to release tag — tracking main pulls in macOS 26 APIs that
    # require Xcode 26 beta. Release tags are stable with Xcode 16.x.
    ghostty.url = "github:ghostty-org/ghostty/v1.3.0";
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
    workspace-config = {
      url = "github:pleme-io/workspace-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dev-tools = {
      url = "github:pleme-io/dev-tools";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.substrate.follows = "substrate";
    };
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    forge = {
      url = "github:pleme-io/forge";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ghostty, substrate, blackmatter-macos, blackmatter-zig, workspace-config, dev-tools, devenv, forge }:
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
      # Guard against empty attrset probe from nix flake check schema validation
      overlays.default = final: prev:
        lib.optionalAttrs (prev ? stdenv) (
          (if prev.stdenv.isDarwin then {
            ghostty = self.packages.${prev.stdenv.hostPlatform.system}.ghostty;
            ghostty-bin = prev.callPackage ./pkgs/ghostty-bin.nix {};
          } else
            ghostty.overlays.default final prev)
          // {
            workspace-config = workspace-config.packages.${prev.stdenv.hostPlatform.system}.default;
          }
        );

      # ── Apps ─────────────────────────────────────────────────────
      apps = forAllSystems (system: let
        pkgs = import nixpkgs { inherit system; };
        forgeCmd = "${forge.packages.${system}.default}/bin/forge";
        releaseHelpers = import "${substrate}/lib/release-helpers.nix";
      in {
        lock-platform = releaseHelpers.mkLockPlatformApp {
          hostPkgs = pkgs;
          toolName = "ghostty";
          language = "nix";
          inherit forgeCmd;
        };
      });

      # ── Home-manager module ──────────────────────────────────────
      homeManagerModules.default = import ./module;

      # ── Dev shells ────────────────────────────────────────────────
      devShells = lib.genAttrs allSystems (system: let
        pkgs = import nixpkgs { inherit system; };
        darwinShells = lib.optionalAttrs (isDarwin system) (let
          dpkgs = darwinPkgs system;
        in {
          default = dpkgs.mkShell {
            buildInputs = [
              dpkgs.zigToolchain
              dpkgs.swiftToolchain
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
      in darwinShells // {
        devenv = devenv.lib.mkShell {
          inputs = { inherit nixpkgs devenv; };
          inherit pkgs;
          modules = [{
            languages.nix.enable = true;
            packages = with pkgs; [ nixpkgs-fmt nil ];
            git-hooks.hooks.nixpkgs-fmt.enable = true;
          }];
        };
      });

      # ── Checks ──────────────────────────────────────────────────
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };

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

          # Verify workspace options evaluate correctly
          module-workspaces = let
            wsEval = lib.evalModules {
              modules = [
                ./module
                (mkHmStubs pkgs)
                ({ ... }: {
                  config.blackmatter.components.ghostty = {
                    enable = true;
                    workspaces = {
                      infra = {
                        displayName = "Infrastructure";
                        theme.cursorColor = "#BF616A";
                        theme.selectionBackground = "#3B4252";
                        extraConfig = "background-opacity = 0.9";
                      };
                      code = {
                        displayName = "Code";
                      };
                    };
                  };
                })
              ];
            };
            infraFile = wsEval.config.home.file.".config/ghostty/config-infra";
            codeFile = wsEval.config.home.file.".config/ghostty/config-code";
          in pkgs.runCommand "ghostty-module-workspaces" {} ''
            echo "Workspaces defined: ${builtins.toJSON (builtins.attrNames wsEval.config.blackmatter.components.ghostty.workspaces)}"
            echo "Infra display name: ${wsEval.config.blackmatter.components.ghostty.workspaces.infra.displayName}"
            echo "Infra cursor color: ${builtins.toJSON wsEval.config.blackmatter.components.ghostty.workspaces.infra.theme.cursorColor}"
            echo "Code display name: ${wsEval.config.blackmatter.components.ghostty.workspaces.code.displayName}"
            echo "Config file exists for infra: ${builtins.toJSON (builtins.hasAttr ".config/ghostty/config-infra" wsEval.config.home.file)}"
            echo "Config file exists for code: ${builtins.toJSON (builtins.hasAttr ".config/ghostty/config-code" wsEval.config.home.file)}"
            echo "Wrapper packages count: ${builtins.toJSON (builtins.length wsEval.config.home.packages)}"

            # Verify config files use source (symlink to store path, no IFD)
            echo "Infra config source: ${infraFile.source}"
            echo "Code config source: ${codeFile.source}"

            # Verify generated config content is correct
            grep -q "# Ghostty Workspace: infra" "${infraFile.source}"
            grep -q "cursor-color = #BF616A" "${infraFile.source}"
            grep -q "selection-background = #3B4252" "${infraFile.source}"
            grep -q "title = Infrastructure" "${infraFile.source}"
            grep -q "background-opacity = 0.9" "${infraFile.source}"
            grep -q "# Ghostty Workspace: code" "${codeFile.source}"
            grep -q "title = Code" "${codeFile.source}"
            echo "Config content verified"

            # Derive artifacts base path from config source and verify runtime YAML + apps
            artifacts=$(dirname "$(dirname "${infraFile.source}")")

            # Verify YAML runtime config (shikumi convention, consumed by multicall exec)
            test -f "$artifacts/wrappers/wrappers.yaml" || (echo "FAIL: wrappers.yaml missing" && exit 1)
            grep -q 'binaryName.*ghostty-infra' "$artifacts/wrappers/wrappers.yaml"
            grep -q 'binaryName.*ghostty-code' "$artifacts/wrappers/wrappers.yaml"
            grep -q 'workspace.*infra' "$artifacts/wrappers/wrappers.yaml"
            grep -q 'workspace.*code' "$artifacts/wrappers/wrappers.yaml"
            echo "Runtime YAML config verified"

            # Verify binary-names list (consumed by Nix to create symlinks)
            test -f "$artifacts/wrappers/binary-names" || (echo "FAIL: binary-names missing" && exit 1)
            grep -q 'ghostty-infra' "$artifacts/wrappers/binary-names"
            grep -q 'ghostty-code' "$artifacts/wrappers/binary-names"
            echo "Binary names list verified"

            # Verify macOS .app bundles (Info.plist only — Nix adds the executable symlink)
            test -f "$artifacts/Applications/Ghostty Infrastructure.app/Contents/Info.plist" || (echo "FAIL: infra .app missing" && exit 1)
            test -f "$artifacts/Applications/Ghostty Code.app/Contents/Info.plist" || (echo "FAIL: code .app missing" && exit 1)
            grep -q "CFBundleName" "$artifacts/Applications/Ghostty Infrastructure.app/Contents/Info.plist"
            grep -q "ghostty-infra" "$artifacts/Applications/Ghostty Infrastructure.app/Contents/Info.plist"
            grep -q "ghostty-code" "$artifacts/Applications/Ghostty Code.app/Contents/Info.plist"
            echo "App bundles verified"

            touch $out
          '';

          # Verify workspace-config CLI works (validate subcommand)
          workspace-config-validate = pkgs.runCommand "workspace-config-validate" {
            nativeBuildInputs = [ pkgs.workspace-config ];
          } ''
            echo '${builtins.toJSON {
              baseConfigPath = "/test/config";
              ghosttyBin = "/test/ghostty";
              bundleIdPrefix = "io.test";
              workspaces = [
                { name = "alpha"; displayName = "Alpha"; theme = { cursorColor = "#A3BE8C"; selectionBackground = null; background = null; }; extraConfig = ""; }
                { name = "beta"; displayName = "Beta"; theme = { cursorColor = null; selectionBackground = null; background = null; }; extraConfig = ""; }
              ];
            }}' > input.json
            workspace-config validate --input input.json 2>&1 | grep -q "valid: 2"
            echo "workspace-config validate passed"
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
