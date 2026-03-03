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
  postPatch = ''
    cp ${./patches/GhosttyXCFramework.zig} src/build/GhosttyXCFramework.zig
    cp ${./patches/MetallibStep.zig} src/build/MetallibStep.zig
    cp ${./patches/GhosttyXcodebuild.zig} src/build/GhosttyXcodebuild.zig

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
