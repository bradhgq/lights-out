{ lib, stdenvNoCC, fetchurl }:

stdenvNoCC.mkDerivation rec {
  pname = "lights-out";
  version = "1.0.0";

  # To use a pre-built release:
  #   nix build .# -- uses the source build below
  # To override with a local .app bundle:
  #   nix build .# --override-input ... or pass src
  src = ../.;

  # Impure build: uses the host's Swift toolchain (requires Xcode CLT)
  # This is macOS-only and Swift-in-Nix is unreliable, so we shell out.
  __noChroot = true;

  buildPhase = ''
    runHook preBuild

    # Use system Swift toolchain
    export PATH="/usr/bin:$PATH"

    # SwiftPM needs a writable HOME for its cache/manifest db
    export HOME=$(mktemp -d)

    # Disable SwiftPM's internal sandbox — it calls sandbox-exec which
    # is blocked in the nix build environment (Determinate Nix)
    swift build -c release --disable-sandbox

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Create .app bundle structure
    APP="$out/Applications/LightsOut.app/Contents"
    mkdir -p "$APP/MacOS" "$APP/Resources"

    cp .build/release/LightsOut "$APP/MacOS/LightsOut"
    cp .build/release/LightsOutHelper "$APP/MacOS/LightsOutHelper"
    cp resources/Info.plist "$APP/Info.plist"
    cp resources/com.lightsout.helper.plist "$APP/Resources/com.lightsout.helper.plist"

    # Skip actool (requires Xcode) — app works without custom icon
    # If you have Xcode CLT, uncomment:
    # xcrun actool resources/Assets.xcassets \
    #   --compile "$APP/Resources" \
    #   --platform macosx \
    #   --minimum-deployment-target 13.0 \
    #   --app-icon AppIcon \
    #   --output-partial-info-plist /dev/null

    # Also install binaries to bin/ for direct access
    mkdir -p "$out/bin"
    ln -s "$APP/MacOS/LightsOut" "$out/bin/lights-out"
    ln -s "$APP/MacOS/LightsOutHelper" "$out/bin/lights-out-helper"

    runHook postInstall
  '';

  meta = with lib; {
    description = "macOS menubar app that enforces evening wind-down routines";
    homepage = "https://github.com/bradhgq/lights-out";
    license = licenses.mit;
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    mainProgram = "lights-out";
  };
}
