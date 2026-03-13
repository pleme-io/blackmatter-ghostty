# pkgs/ghostty-darwin.nix
# Ghostty macOS source build using mkZigSwiftApp from blackmatter-macos.
# Requires system Xcode (impure build with __noChroot = true).
#
# Build environment discovery, pbxproj patching, framework vendoring, and
# app bundle installation are handled by nix-macos (dev-tools).
{ pkgs, lib, mkZigSwiftApp, ghosttySrc, nix-macos }:
let
  deps = pkgs.callPackage "${ghosttySrc}/build.zig.zon.nix" {
    name = "ghostty-deps";
    zig_0_15 = pkgs.zigToolchain;
  };

  version = "1.3.0";
in
mkZigSwiftApp {
  pname = "Ghostty";
  inherit version;
  src = ghosttySrc;
  bundleIdentifier = "com.mitchellh.ghostty";

  # Ghostty's macOS build uses SwiftUI
  needsSwiftUI = true;

  zigBuildFlags = [
    "--system" "${deps}"
    "-Doptimize=ReleaseFast"
    "-Dcpu=baseline"
    "-Dxcframework-target=native"
  ];

  # Ghostty's zig build spawns pandoc (docs) and msgfmt (i18n) as subprocesses
  extraNativeBuildInputs = [ pkgs.pandoc pkgs.gettext nix-macos ];

  entitlements = {
    allowJit = true;
    disableLibraryValidation = true;
  };

  # Patch 1: Skip iOS/iOS Simulator targets when building native-only.
  # Patch 2: Call metal/metallib directly from PATH instead of via xcrun.
  # Patch 3: Pass through env vars for xcodebuild + vendored Sparkle framework.
  # Patch 4: Remove Sparkle SPM dependency — SwiftPM calls /usr/bin/sandbox-exec
  #   (absolute path) during package resolution, and the Nix daemon user can't
  #   use sandbox-exec. We vendor Sparkle.xcframework and pass it via build settings.
  # Patch 5: Xcode 16.x compatibility — macOS 26 APIs (NSGlassEffectView,
  #   ConcentricRectangle) don't exist in Xcode 16.x SDK. Also fixes Swift 6
  #   strict concurrency 'sending' error in DockTilePlugin.
  #   Uses patched file copies instead of a diff patch for easier maintenance.
  postPatch = ''
    cp ${./patches/GhosttyXCFramework.zig} src/build/GhosttyXCFramework.zig
    cp ${./patches/MetallibStep.zig} src/build/MetallibStep.zig
    cp ${./patches/GhosttyXcodebuild.zig} src/build/GhosttyXcodebuild.zig

    # Xcode 16.x compat: replace files that use macOS 26-only APIs
    _xcodeMajor="$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}' | cut -d. -f1)"
    if [ -n "$_xcodeMajor" ] && [ "$_xcodeMajor" -lt 26 ]; then
      echo "ghostty-darwin: Xcode $_xcodeMajor detected (< 26), applying Xcode 16.x compat files"
      cp ${./patches/xcode16-compat/Features/Custom\ App\ Icon/DockTilePlugin.swift} "macos/Sources/Features/Custom App Icon/DockTilePlugin.swift"
      cp ${./patches/xcode16-compat/Ghostty/Surface\ View/SurfaceView.swift} "macos/Sources/Ghostty/Surface View/SurfaceView.swift"
      cp ${./patches/xcode16-compat/Helpers/Backport.swift} "macos/Sources/Helpers/Backport.swift"
    else
      echo "ghostty-darwin: Xcode $_xcodeMajor detected (>= 26), skipping Xcode 16.x compat files"
    fi

    nix-macos pbxproj strip-spm macos/Ghostty.xcodeproj/project.pbxproj

    nix-macos vendor-framework \
      --github sparkle-project/Sparkle \
      --version 2.9.0 \
      --asset "Sparkle-for-Swift-Package-Manager.zip" \
      --output macos/Frameworks
  '';

  buildPhaseOverride = ''
    runHook preBuild

    eval "$(nix-macos env)"

    # --- Platform detection and early error reporting ---
    echo "ghostty-darwin: detecting build platform..."

    # 1. Platform check
    nixSystem="${pkgs.stdenv.hostPlatform.system}"
    case "$nixSystem" in
      aarch64-darwin|x86_64-darwin)
        echo "  platform: $nixSystem (supported)"
        ;;
      *)
        echo "ERROR: Unsupported platform '$nixSystem'."
        echo "  Ghostty macOS source build requires aarch64-darwin or x86_64-darwin."
        exit 1
        ;;
    esac

    # 2. Xcode check
    if ! command -v xcodebuild &>/dev/null; then
      echo "ERROR: Xcode is not installed (xcodebuild not found in PATH)."
      echo "  Install Xcode from the App Store or https://developer.apple.com/xcode/"
      exit 1
    fi

    xcodeVersion="$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')"
    echo "  Xcode: $xcodeVersion"

    xcodeMajor="$(echo "$xcodeVersion" | cut -d. -f1)"
    if [ -z "$xcodeMajor" ] || [ "$xcodeMajor" -lt 16 ]; then
      echo "ERROR: Xcode $xcodeVersion is too old. Minimum supported version is 16.0."
      echo "  Update Xcode from the App Store or https://developer.apple.com/xcode/"
      exit 1
    fi

    # 3. macOS version
    if command -v sw_vers &>/dev/null; then
      macosVersion="$(sw_vers -productVersion)"
      echo "  macOS: $macosVersion"
    else
      echo "  macOS: unknown (sw_vers not found)"
    fi

    # 4. Swift version
    if command -v swiftc &>/dev/null; then
      swiftVersion="$(swiftc --version 2>/dev/null | head -1)"
      echo "  Swift: $swiftVersion"
    else
      echo "  Swift: not found (will rely on SWIFT_EXEC from nix-macos env)"
    fi

    echo "ghostty-darwin: platform checks passed."
    # --- End platform detection ---

    # Sparkle.xcframework was extracted to macos/Frameworks/ in postPatch.
    # The macOS framework slice is at Sparkle.xcframework/macos-arm64_x86_64/.
    # Export path for the Zig build to pass as FRAMEWORK_SEARCH_PATHS.
    export GHOSTTY_SPARKLE_PATH="$(pwd)/macos/Frameworks/Sparkle.xcframework/macos-arm64_x86_64"

    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/.zig-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/.zig-cache"

    # Do NOT use --prefix here. xcodebuild's CpResource expects resources
    # at zig-out/share/ (relative to source). --prefix redirects install
    # outputs away from zig-out/, causing CpResource to fail.
    # We copy from zig-out/ and macos/build/ to $out in installPhaseOverride.
    zig build \
      --system ${deps} \
      -Doptimize=ReleaseFast \
      -Dcpu=baseline \
      -Dxcframework-target=native \
      2>&1

    runHook postBuild
  '';

  installPhaseOverride = ''
    runHook preInstall

    nix-macos bundle install \
      --search-dir macos/build \
      --app-name Ghostty.app \
      --output "$out" \
      --embed-framework "macos/Frameworks/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" \
      --symlink-resource terminfo \
      --symlink-resource shell-integration \
      --bin-dir zig-out/bin

    runHook postInstall
  '';

  meta = {
    description = "Ghostty terminal emulator (built from source)";
    homepage = "https://ghostty.org";
    license = lib.licenses.mit;
    mainProgram = "ghostty";
  };
}
