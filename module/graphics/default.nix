# graphics/default.nix
# Re-exports all graphical effect modules for clean imports.
{ lib }:
{
  shaderPipeline = import ./shader-pipeline.nix { inherit lib; };
  theme = import ./theme.nix { inherit lib; };
  settings = import ./settings.nix { inherit lib; };
}
