# pkgs/ghostty-darwin.nix
# Ghostty macOS source build using mkZigSwiftApp from blackmatter-macos.
# Requires system Xcode (impure build with __noChroot = true).
{ pkgs, lib, mkZigSwiftApp, ghosttySrc }:
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
  extraNativeBuildInputs = [ pkgs.pandoc pkgs.gettext ];

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

    # Strip all Sparkle SPM references from the Xcode project.
    pbxproj=macos/Ghostty.xcodeproj/project.pbxproj

    # Remove PBXBuildFile for Sparkle SPM product
    sed -i '/A51BFC272B30F1B800E92F16/d' "$pbxproj"
    # Remove XCSwiftPackageProductDependency reference
    sed -i '/A51BFC262B30F1B800E92F16/d' "$pbxproj"
    # Remove XCRemoteSwiftPackageReference reference
    sed -i '/A51BFC252B30F1B700E92F16/d' "$pbxproj"
    # Remove the entire XCRemoteSwiftPackageReference section
    sed -i '/Begin XCRemoteSwiftPackageReference section/,/End XCRemoteSwiftPackageReference section/d' "$pbxproj"
    # Remove the entire XCSwiftPackageProductDependency section
    sed -i '/Begin XCSwiftPackageProductDependency section/,/End XCSwiftPackageProductDependency section/d' "$pbxproj"

    # Download Sparkle.xcframework binary and vendor it in the source tree.
    mkdir -p macos/Frameworks
    echo "Downloading Sparkle 2.9.0 xcframework..."
    /usr/bin/curl -L --fail --cacert /etc/ssl/cert.pem -o "$TMPDIR/sparkle-spm.zip" \
      "https://github.com/sparkle-project/Sparkle/releases/download/2.9.0/Sparkle-for-Swift-Package-Manager.zip"
    /usr/bin/unzip -q "$TMPDIR/sparkle-spm.zip" -d macos/Frameworks/
    echo "Sparkle xcframework extracted to macos/Frameworks/"
    ls -la macos/Frameworks/
  '';

  buildPhaseOverride = ''
    runHook preBuild

    # Point to Xcode.app so xcrun can find xcodebuild, swiftc, etc.
    # xcode-select may default to CLI Tools which lacks these.
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

    # Add Metal Toolchain binaries (cryptex mount) directly to PATH.
    # The Xcode metal stub can't exec the cryptex binary in the Nix
    # daemon sandbox, so we call metal/metallib directly.
    for d in /var/run/com.apple.security.cryptexd/mnt/com.apple.MobileAsset.MetalToolchain*/Metal.xctoolchain/usr/bin; do
      if [ -d "$d" ]; then
        export PATH="$d:$PATH"
        break
      fi
    done

    # Zig's findNative spawns xcode-select/xcrun as subprocesses to discover
    # the macOS SDK. __noChroot makes /usr/bin accessible but doesn't add it
    # to PATH — we must do that explicitly.
    # APPEND (not prepend) so Nix GNU tools (find, cut) keep priority over
    # macOS BSD variants — the fixup phase needs GNU-specific flags.
    export PATH="$PATH:/usr/bin"

    # Nix daemon HOME is /var/empty (read-only). xcodebuild needs a
    # writable HOME for DerivedData, SourcePackages, and log stores.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"

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

    # The app bundle is at macos/build/<config>/Ghostty.app (built by xcodebuild).
    # Zig's install step also copies it, but the canonical output is in macos/build/.
    app_src=""
    for d in macos/build/*/Ghostty.app; do
      if [ -d "$d" ]; then
        app_src="$d"
        break
      fi
    done

    if [ -z "$app_src" ]; then
      echo "ERROR: Ghostty.app not found in macos/build/"
      exit 1
    fi

    mkdir -p "$out/Applications"
    cp -R "$app_src" "$out/Applications/"

    # CLI binary from zig-out/bin/
    if [ -d "zig-out/bin" ]; then
      mkdir -p "$out/bin"
      cp -R zig-out/bin/* "$out/bin/"
    fi

    # Embed Sparkle.framework in the app bundle for runtime linking.
    sparkle_fw="macos/Frameworks/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
    if [ -d "$sparkle_fw" ]; then
      mkdir -p "$out/Applications/Ghostty.app/Contents/Frameworks"
      cp -R "$sparkle_fw" "$out/Applications/Ghostty.app/Contents/Frameworks/"
    fi

    # Symlink terminfo + shell-integration resources into share/
    for res in terminfo shell-integration; do
      src_path="$out/Applications/Ghostty.app/Contents/Resources/$res"
      if [ -d "$src_path" ]; then
        mkdir -p "$out/share"
        ln -sf "$src_path" "$out/share/$res"
      fi
    done

    runHook postInstall
  '';

  meta = {
    description = "Ghostty terminal emulator (built from source)";
    homepage = "https://ghostty.org";
    license = lib.licenses.mit;
    mainProgram = "ghostty";
  };
}
