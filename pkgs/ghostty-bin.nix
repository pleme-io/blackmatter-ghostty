# Prebuilt Ghostty binary from official releases.
# Used when darwin.useSourceBuild = false (default).
# No Xcode or Metal toolchain required.
{ lib, stdenvNoCC, fetchurl, _7zz }:

stdenvNoCC.mkDerivation rec {
  pname = "Ghostty-bin";
  version = "1.3.1";

  src = fetchurl {
    url = "https://release.files.ghostty.org/${version}/Ghostty.dmg";
    sha256 = "18cff2b0a6cee90eead9c7d3064e808a252a40baf214aa752c1ecb793b8f5f69";
  };

  nativeBuildInputs = [ _7zz ];

  # 7zz warns about "dangerous" relative symlinks in terminfo but extracts fine
  unpackPhase = ''
    7zz x "$src" -ocontents || true
  '';

  sourceRoot = "contents/Ghostty.app";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications/Ghostty.app"
    cp -R . "$out/Applications/Ghostty.app/"
    mkdir -p "$out/bin"
    ln -sf "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" "$out/bin/ghostty"
    runHook postInstall
  '';

  meta = {
    description = "Ghostty terminal emulator (prebuilt binary)";
    homepage = "https://ghostty.org/";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "ghostty";
  };
}
