{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}:

# The released binary avoids the Go source build that the upstream flake
# needs, and pins one version and one hash.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bv";
  version = "0.29.0";

  src = fetchurl {
    url = "https://github.com/Dicklesworthstone/beads_viewer/releases/download/v${finalAttrs.version}/bv_${finalAttrs.version}_darwin_arm64.tar.gz";
    hash = "sha256-NyR5Q6rVFs9met0wyUADRnPx5T+K4CTTsjxsjcYmX7A=";
  };

  # The archive has no top-level folder.
  sourceRoot = ".";

  dontBuild = true;
  # Keep the released executable byte-for-byte intact.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bv "$out/bin/bv"
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Viewer and Markdown exporter for br issue data, with dependency graphs";
    homepage = "https://github.com/Dicklesworthstone/beads_viewer";
    changelog = "https://github.com/Dicklesworthstone/beads_viewer/releases/tag/v${finalAttrs.version}";
    license = {
      shortName = "MIT+OpenAI-Anthropic-Rider";
      fullName = "MIT License with OpenAI/Anthropic Rider";
      url = "https://github.com/Dicklesworthstone/beads_viewer/blob/main/LICENSE";
      free = false;
      redistributable = false;
    };
    mainProgram = "bv";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
