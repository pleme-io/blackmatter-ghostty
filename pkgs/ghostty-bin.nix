# Prebuilt Ghostty binary from official releases.
# Used when darwin.useSourceBuild = false (default).
# No Xcode or Metal toolchain required.
{ lib, stdenvNoCC, fetchurl, _7zz, gawk }:

stdenvNoCC.mkDerivation rec {
  pname = "Ghostty-bin";
  version = "1.3.1";

  src = fetchurl {
    url = "https://release.files.ghostty.org/${version}/Ghostty.dmg";
    sha256 = "18cff2b0a6cee90eead9c7d3064e808a252a40baf214aa752c1ecb793b8f5f69";
  };

  nativeBuildInputs = [ _7zz gawk ];

  # Ghostty ships an APFS DMG (undmg only handles HFS+), so we use 7zz.
  # 7zz rejects relative symlinks with ".." prefixes (e.g. terminfo/67/ghostty
  # -> .././78/xterm-ghostty) as "dangerous", leaving 0-byte placeholders.
  # Those placeholders break the embedded code signature because
  # Contents/_CodeSignature/CodeResources still hashes the original symlinks
  # → macOS Gatekeeper: "Ghostty.app is damaged and can't be opened".
  #
  # Fix: parse 7zz's own archive listing, then recreate every symlink the
  # extractor refused to materialize. symlink hashes in codesign depend on
  # the target string, so a byte-identical target re-validates the seal.
  unpackPhase = ''
    runHook preUnpack
    mkdir -p contents

    # Extract; failures on dangerous symlinks are non-fatal and repaired below.
    7zz x "$src" -ocontents >/dev/null || true

    # Gather (path \t target) tuples for every symlink in the DMG.
    7zz l -slt "$src" \
      | awk -v RS="" '
          {
            path=""; target="";
            n = split($0, lines, "\n");
            for (i = 1; i <= n; i++) {
              if (match(lines[i], /^Path = /))           path   = substr(lines[i], 8);
              if (match(lines[i], /^Symbolic Link = /))  target = substr(lines[i], 17);
            }
            if (path != "" && target != "" && path != "Applications") {
              print path "\t" target;
            }
          }
        ' > symlinks.tsv

    repaired=0
    while IFS=$'\t' read -r path target; do
      full="contents/$path"
      if [ ! -L "$full" ]; then
        rm -rf "$full"
        mkdir -p "$(dirname "$full")"
        ln -s "$target" "$full"
        repaired=$((repaired + 1))
      fi
    done < symlinks.tsv
    echo "ghostty-bin: repaired $repaired dropped symlink(s)"

    runHook postUnpack
  '';

  sourceRoot = "contents/Ghostty.app";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/Ghostty.app"
    cp -RP . "$out/Applications/Ghostty.app/"
    mkdir -p "$out/bin"
    ln -sf "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" "$out/bin/ghostty"
    runHook postInstall
  '';

  # Verify the bundle signature survived extraction (darwin only).
  doInstallCheck = stdenvNoCC.isDarwin;
  installCheckPhase = ''
    runHook preInstallCheck
    if ! /usr/bin/codesign --verify --verbose=1 "$out/Applications/Ghostty.app" 2>&1; then
      echo "ERROR: Ghostty.app signature is broken after extraction." >&2
      echo "       macOS Gatekeeper will refuse to launch the bundle." >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Ghostty terminal emulator (prebuilt binary)";
    homepage = "https://ghostty.org/";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "ghostty";
  };
}
