# blackmatter-ghostty

Nix module and source build for the [Ghostty](https://ghostty.org) GPU-accelerated
terminal emulator. Provides a home-manager module with an opinionated Nord theme,
GLSL shader effects, and curated keybindings. On macOS, supports building Ghostty
from source using Zig + Swift via `mkZigSwiftApp` (requires Xcode). On Linux,
re-exports the upstream Ghostty package.

## Architecture

```
ghostty (upstream src)     substrate (Zig/Swift overlays)
        |                          |
        v                          v
  pkgs/ghostty-darwin.nix   blackmatter-macos (mkZigSwiftApp)
        |                          |
        +-----+--------------------+
              |
              v
        packages.ghostty  ---------> overlays.default
              |
              v
        module/default.nix  --------> homeManagerModules.default
         |        |       |
         v        v       v
   themes/    shaders/   keybindings
   (Nord)    (bloom,     (prompt nav,
              cursor      splits,
              trail)      quick term)
```

**Darwin build flow:** Ghostty source is compiled via a 3-stage process:
1. **Zig build** — compiles the core terminal engine (libghostty), resources (terminfo,
   shell-integration), and Metal shaders
2. **Xcodebuild** — builds the Swift/SwiftUI macOS app shell using the Zig-built
   xcframework
3. **Bundle install** — assembles the final `Ghostty.app` with embedded frameworks
   (Sparkle for auto-updates), resources, and CLI symlinks

The Darwin build is **impure** (`__noChroot = true`) because it requires system Xcode
for SwiftUI compilation and Metal shader toolchain.

## Features

- **Nord color theme** — enhanced 16-color palette based on the [Nord](https://www.nordtheme.com) palette, with custom foreground/selection tuning for elegance
- **GLSL shaders** — optional bloom glow and cursor trail effects
- **Curated keybindings** — prompt navigation (cmd+up/down), split management (ctrl+shift+arrows), quick terminal toggle (cmd+grave)
- **Shell integration** — cursor, sudo, title, ssh-env, ssh-terminfo features enabled by default
- **Dual platform** — Linux uses home-manager's `programs.ghostty`; macOS writes config directly to `~/.config/ghostty/config`
- **Source build option** — build Ghostty from source on macOS instead of using prebuilt binary
- **Full customization** — every setting exposed as a typed NixOS option with sensible defaults

## Installation / Getting Started

### As a Flake Input

```nix
{
  inputs.blackmatter-ghostty = {
    url = "github:pleme-io/blackmatter-ghostty";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.substrate.follows = "substrate";
    inputs.blackmatter-zig.follows = "blackmatter-zig";
  };
}
```

### Home-Manager Module

```nix
{
  imports = [ inputs.blackmatter-ghostty.homeManagerModules.default ];

  blackmatter.components.ghostty = {
    enable = true;
    # All other options have sensible defaults
  };
}
```

### Overlay

```nix
{
  nixpkgs.overlays = [ inputs.blackmatter-ghostty.overlays.default ];
  # Provides: pkgs.ghostty (source build on Darwin, upstream on Linux)
}
```

## Configuration

All options live under `blackmatter.components.ghostty`. Defaults shown below.

### Font

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `font.family` | string | `"JetBrains Mono"` | Font family |
| `font.size` | int | `12` | Font size |
| `font.thicken` | bool | `true` | Font thickening for readability |
| `font.adjustCellHeight` | int | `0` | Cell height adjustment (%) |

### Window

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `window.paddingX` | int | `12` | Horizontal padding (px) |
| `window.paddingY` | int | `12` | Vertical padding (px) |
| `window.decoration` | bool | `true` | Window decorations |
| `window.gtkTitlebar` | bool | `true` | GTK titlebar (Linux) |

### Appearance

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `appearance.backgroundOpacity` | float | `0.95` | Background opacity |
| `appearance.backgroundBlurRadius` | int | `32` | Background blur (px) |
| `appearance.unfocusedSplitOpacity` | float | `0.8` | Unfocused split opacity |
| `appearance.boldIsBright` | bool | `false` | Bold text uses bright colors |
| `appearance.windowColorspace` | string | `"srgb"` | Colorspace (srgb or display-p3) |
| `appearance.macosTitlebarStyle` | enum | `"transparent"` | native, transparent, or tabs |
| `appearance.fontThickenStrength` | int | `70` | Font thicken strength (0-255, macOS) |

### Theme

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme.nordTheme` | bool | `true` | Use enhanced Nord color theme |
| `theme.useBuiltinNord` | bool | `false` | Use Ghostty's built-in Nord instead of custom |
| `theme.customColors` | attrs | `{}` | Color overrides (background, foreground, etc.) |

### Cursor

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cursor.style` | enum | `"block"` | block, bar, or underline |
| `cursor.blink` | bool | `true` | Cursor blinking |

### Shaders

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `shaders.enable` | bool | `false` | Enable GLSL shader effects |
| `shaders.bloom` | bool | `true` | Subtle bloom glow on bright text |
| `shaders.cursorTrail` | bool | `true` | Cursor trail effect |
| `shaders.animation` | bool | `true` | Shader animation |
| `shaders.custom` | list of paths | `[]` | Additional custom shader files |

### Keybindings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `keybindings.enable` | bool | `true` | Enable curated keybindings |
| `keybindings.promptNavigation` | bool | `true` | cmd+up/down to jump prompts |
| `keybindings.splitManagement` | bool | `true` | ctrl+shift+arrows for splits |
| `keybindings.quickTerminal` | bool | `true` | cmd+grave for quick terminal |
| `keybindings.custom` | list of strings | `[]` | Additional keybindings |

### Darwin-Specific

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `darwin.useSourceBuild` | bool | `false` | Build from source (requires Xcode) |

### Other

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `extraSettings` | attrs | `{}` | Additional Ghostty settings (key-value) |

## Usage Examples

### Minimal Setup

```nix
blackmatter.components.ghostty.enable = true;
```

### Full Customization

```nix
blackmatter.components.ghostty = {
  enable = true;
  font.family = "FiraCode Nerd Font";
  font.size = 14;
  appearance.backgroundOpacity = 0.90;
  appearance.macosTitlebarStyle = "tabs";
  cursor.style = "bar";
  shaders.enable = true;
  keybindings.custom = [ "ctrl+shift+c=copy_to_clipboard" ];
  darwin.useSourceBuild = true;  # Build from source on macOS
  extraSettings = { "macos-option-as-alt" = true; };
};
```

## Development

### Build from Source (macOS)

Requires Xcode installed at `/Applications/Xcode.app`.

```bash
# Build the macOS app (~40 min on M4)
nix build .#ghostty --impure

# Result is a symlink to the Nix store containing Ghostty.app
ls -la result/Applications/Ghostty.app
```

### Dev Shell

```bash
nix develop    # Provides Zig + Swift toolchains
```

### Run Checks

```bash
nix flake check    # Module evaluation, theme colors, shaders, keybindings
```

Checks verify:
- Module options exist and are well-formed
- Nord palette structure is complete (16 colors)
- Module enables correctly on both Darwin and Linux
- Shader-enabled configuration evaluates
- Keybinding configuration evaluates
- `darwin.useSourceBuild` option works (Darwin only)

## Source Build Patches

The macOS source build applies four patches to upstream Ghostty:

1. **GhosttyXCFramework.zig** — skips iOS/iOS Simulator targets for native-only builds
2. **MetallibStep.zig** — invokes `metal`/`metallib` directly from PATH instead of via `xcrun` (required because `xcrun` cannot execute cryptex-mounted binaries inside the Nix sandbox)
3. **GhosttyXcodebuild.zig** — passes through environment variables (HOME, DEVELOPER_DIR, TMPDIR, PATH) to xcodebuild and adds vendored Sparkle framework search paths
4. **pbxproj strip-spm** — removes Sparkle SPM dependency from the Xcode project (SwiftPM calls `/usr/bin/sandbox-exec` which the Nix daemon user cannot use)

Sparkle is vendored as an xcframework and embedded during the install phase.

## Project Structure

```
blackmatter-ghostty/
  flake.nix                          # Flake — packages, overlay, HM module, checks
  module/
    default.nix                      # Home-manager module (all config options)
    themes/
      nord/colors.nix                # Nord palette definition (16 colors)
    shaders/
      bloom.glsl                     # Bloom glow shader
      cursor-trail.glsl              # Cursor trail shader
  pkgs/
    ghostty-darwin.nix               # macOS source build derivation
    patches/
      GhosttyXCFramework.zig         # Skip iOS targets
      GhosttyXcodebuild.zig          # Env passthrough + Sparkle framework paths
      MetallibStep.zig               # Direct Metal toolchain invocation
```

## Related Projects

- [Ghostty](https://ghostty.org) — upstream terminal emulator
- [blackmatter-macos](https://github.com/pleme-io/blackmatter-macos) — `mkZigSwiftApp` builder used for the macOS source build
- [blackmatter-zig](https://github.com/pleme-io/blackmatter-zig) — Zig toolchain overlay
- [substrate](https://github.com/pleme-io/substrate) — Nix build patterns and toolchain overlays
- [dev-tools](https://github.com/pleme-io/dev-tools) — `nix-macos` CLI used for build environment discovery and app bundle installation

## License

MIT
