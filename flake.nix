{
  description = "Blackmatter Ghostty - GPU-accelerated terminal built from source";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/d6c71932130818840fc8fe9509cf50be8c64634f";
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = { self, nixpkgs, ghostty }:
    let
      buildSystems = [ "x86_64-linux" "aarch64-linux" ];
      forBuildSystems = f: nixpkgs.lib.genAttrs buildSystems (system: f system);
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
    };
}
