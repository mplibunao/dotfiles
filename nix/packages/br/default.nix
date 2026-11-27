{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}:

# The released binary avoids the Rust source build that the upstream flake
# needs, and pins one version and one hash.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "br";
  version = "0.7.6";

  src = fetchurl {
    url = "https://github.com/Dicklesworthstone/beads_rust/releases/download/v${finalAttrs.version}/br-${finalAttrs.version}-darwin_arm64.tar.gz";
    hash = "sha256-0BpO9mqlzUAVL8ZIG3je97bf79VtobJt0chLOGA95vY=";
  };

  # The archive has no top-level folder.
  sourceRoot = ".";

  dontBuild = true;
  # Keep the released executable byte-for-byte intact.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 br "$out/bin/br"
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Local issue tracker for coding agents that leaves the project's Git workflow alone";
    homepage = "https://github.com/Dicklesworthstone/beads_rust";
    changelog = "https://github.com/Dicklesworthstone/beads_rust/releases/tag/v${finalAttrs.version}";
    license = {
      shortName = "MIT+OpenAI-Anthropic-Rider";
      fullName = "MIT License with OpenAI/Anthropic Rider";
      url = "https://github.com/Dicklesworthstone/beads_rust/blob/main/LICENSE";
      free = false;
      redistributable = false;
    };
    mainProgram = "br";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
