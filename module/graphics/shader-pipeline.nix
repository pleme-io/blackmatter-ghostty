# graphics/shader-pipeline.nix
# Shader ordering, layer classification, and debug override system.
#
# Shaders compose in strict layer order — each shader's output feeds
# the next as iChannel0:
#
#   geometric → content → atmosphere → cursor → spatial → color → atmosphere → noise
#
# The debug system replaces shader constants with exaggerated values
# for visual verification. Each shader declares its tunable parameters
# and their production/debug values in a single data structure.
{ lib }:
let
  # ── Shader layer definitions ────────────────────────────────────
  # Each entry: { name, option, file, layer, debugParams }
  # debugParams: list of { find, replace } for builtins.replaceStrings
  shaderDefs = [
    {
      name = "screen-curvature";
      option = "screenCurvature";
      file = ../shaders/screen-curvature.glsl;
      layer = "geometric";
      debugParams = [
        { find = "CURVATURE     = 0.012"; replace = "CURVATURE     = 0.06"; }
        { find = "CORNER_DARK   = 0.025"; replace = "CORNER_DARK   = 0.15"; }
      ];
    }
    {
      name = "bloom";
      option = "bloom";
      file = ../shaders/bloom.glsl;
      layer = "content";
      debugParams = [
        { find = "BLOOM_INTENSITY  = 0.20"; replace = "BLOOM_INTENSITY  = 0.80"; }
        { find = "BLOOM_RADIUS     = 5.0";  replace = "BLOOM_RADIUS     = 12.0"; }
        { find = "SCAN_INTENSITY   = 0.025"; replace = "SCAN_INTENSITY   = 0.20"; }
        { find = "VIGNETTE_STRENGTH = 0.18"; replace = "VIGNETTE_STRENGTH = 0.60"; }
        { find = "PULSE_AMOUNT = 0.015";     replace = "PULSE_AMOUNT = 0.12"; }
      ];
    }
    {
      name = "cursor-glow";
      option = "cursorGlow";
      file = ../shaders/cursor-glow.glsl;
      layer = "cursor";
      debugParams = [
        { find = "CORE_INTENSITY  = 0.60"; replace = "CORE_INTENSITY  = 1.0"; }
        { find = "INNER_INTENSITY = 0.14"; replace = "INNER_INTENSITY = 0.45"; }
        { find = "OUTER_RADIUS = 55.0";    replace = "OUTER_RADIUS = 90.0"; }
      ];
    }
    {
      name = "cursor-trail";
      option = "cursorTrail";
      file = ../shaders/cursor-trail.glsl;
      layer = "cursor";
      debugParams = [
        { find = "CORE_INTENSITY  = 0.95"; replace = "CORE_INTENSITY  = 1.0"; }
        { find = "MID_INTENSITY   = 0.18"; replace = "MID_INTENSITY   = 0.50"; }
        { find = "OUTER_RADIUS = 32.0";    replace = "OUTER_RADIUS = 60.0"; }
      ];
    }
    {
      name = "prompt-saber";
      option = "promptSaber";
      file = ../shaders/prompt-saber.glsl;
      layer = "cursor";
      debugParams = [
        { find = "CORE_INTENSITY  = 0.85"; replace = "CORE_INTENSITY  = 1.0"; }
        { find = "INNER_INTENSITY = 0.28"; replace = "INNER_INTENSITY = 0.50"; }
        { find = "OUTER_HALF  = 24.0";     replace = "OUTER_HALF  = 35.0"; }
        { find = "FOCAL_INTENSITY = 0.12"; replace = "FOCAL_INTENSITY = 0.30"; }
      ];
    }
    {
      name = "sonic-boom";
      option = "sonicBoom";
      file = ../shaders/sonic-boom.glsl;
      layer = "cursor-event";
      debugParams = [
        { find = "R1_I = 0.28";     replace = "R1_I = 0.55"; }
        { find = "R1_MAX    = 120.0"; replace = "R1_MAX    = 200.0"; }
        { find = "IMP_I   = 0.55";   replace = "IMP_I   = 0.85"; }
      ];
    }
    {
      name = "spotlight";
      option = "spotlight";
      file = ../shaders/spotlight.glsl;
      layer = "spatial";
      debugParams = [
        { find = "DIM_AMOUNT    = 0.10";  replace = "DIM_AMOUNT    = 0.40"; }
        { find = "INNER_RADIUS  = 250.0"; replace = "INNER_RADIUS  = 150.0"; }
        { find = "OUTER_RADIUS  = 900.0"; replace = "OUTER_RADIUS  = 500.0"; }
      ];
    }
    {
      name = "chromatic-aberration";
      option = "chromaticAberration";
      file = ../shaders/chromatic-aberration.glsl;
      layer = "color";
      debugParams = [
        { find = "MAX_OFFSET    = 1.5";  replace = "MAX_OFFSET    = 10.0"; }
        { find = "FROST_SHIFT   = 0.12"; replace = "FROST_SHIFT   = 0.50"; }
      ];
    }
    {
      name = "background-pulse";
      option = "backgroundPulse";
      file = ../shaders/background-pulse.glsl;
      layer = "atmosphere";
      debugParams = [
        { find = "INTENSITY     = 0.015"; replace = "INTENSITY     = 0.12"; }
        { find = "CYCLE_SPEED   = 0.08";  replace = "CYCLE_SPEED   = 0.5"; }
      ];
    }
    {
      name = "frost-haze";
      option = "frostHaze";
      file = ../shaders/frost-haze.glsl;
      layer = "atmosphere";
      debugParams = [
        { find = "HAZE_OPACITY  = 0.035"; replace = "HAZE_OPACITY  = 0.25"; }
        { find = "EDGE_START    = 0.55";  replace = "EDGE_START    = 0.30"; }
      ];
    }
    {
      name = "film-grain";
      option = "filmGrain";
      file = ../shaders/film-grain.glsl;
      layer = "noise";
      debugParams = [
        { find = "GRAIN_INTENSITY  = 0.025"; replace = "GRAIN_INTENSITY  = 0.25"; }
        { find = "FROST_TINT       = 0.15";  replace = "FROST_TINT       = 0.80"; }
      ];
    }
    {
      name = "stardust";
      option = "stardust";
      file = ../shaders/stardust.glsl;
      layer = "noise";
      debugParams = [
        { find = "STAR_DENSITY    = 0.09";  replace = "STAR_DENSITY    = 0.30"; }
        { find = "STAR_INTENSITY  = 0.06";  replace = "STAR_INTENSITY  = 0.25"; }
        { find = "STAR_RADIUS     = 1.5";   replace = "STAR_RADIUS     = 3.0"; }
        { find = "GRID_SIZE       = 20.0";  replace = "GRID_SIZE       = 14.0"; }
      ];
    }
  ];

  # ── Pipeline builder ────────────────────────────────────────────
  # Returns the ordered list of shader paths, filtered by cfg toggles.
  mkPipeline = cfg:
    let
      enabled = builtins.filter
        (def: cfg.shaders.${def.option} or false)
        shaderDefs;
    in
      map (def: def.file) enabled;

  # ── Debug override builder ──────────────────────────────────────
  # For each shader with debugParams, produces { "name.glsl" = modified-source; }
  mkDebugOverrides =
    let
      mkOverride = def:
        let
          finds    = map (p: p.find) def.debugParams;
          replaces = map (p: p.replace) def.debugParams;
          source   = builtins.readFile def.file;
        in
          lib.nameValuePair
            "${def.name}.glsl"
            (builtins.replaceStrings finds replaces source);

      withParams = builtins.filter (def: def.debugParams != []) shaderDefs;
    in
      builtins.listToAttrs (map mkOverride withParams);

  # ── Home file generator ─────────────────────────────────────────
  # Produces the home.file attrset for shader deployment.
  mkShaderFiles = cfg:
    let
      pipeline = mkPipeline cfg;
      overrides = mkDebugOverrides;
    in
      lib.listToAttrs (map (path:
        let
          name = builtins.baseNameOf (toString path);
          debugContent = overrides.${name} or null;
          useDebug = cfg.shaders.debug && debugContent != null;
        in
          lib.nameValuePair
            ".config/ghostty/shaders/${name}"
            (if useDebug then { text = debugContent; } else { source = path; })
      ) pipeline);

  # ── Shader config lines ─────────────────────────────────────────
  # Returns the ghostty settings for the shader pipeline.
  mkShaderSettings = { cfg, homeDir }:
    let
      pipeline = mkPipeline cfg;
      paths = map (path:
        "${homeDir}/.config/ghostty/shaders/${builtins.baseNameOf (toString path)}"
      ) pipeline;
    in {
      custom-shader-animation = cfg.shaders.animation;
    } // lib.optionalAttrs (paths != []) {
      custom-shader = paths;
    };

in {
  inherit shaderDefs mkPipeline mkDebugOverrides mkShaderFiles mkShaderSettings;
}
