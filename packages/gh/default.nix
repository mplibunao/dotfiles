{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  installShellFiles,
  makeWrapper,
  versionCheckHook,
}:

# The official binary keeps gh current without moving the shared nixpkgs pin
# to obtain the newer Go toolchain required by its source build.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gh";
  version = "2.102.0";

  src = fetchurl {
    url = "https://github.com/cli/cli/releases/download/v${finalAttrs.version}/gh_${finalAttrs.version}_macOS_arm64.zip";
    hash = "sha256-2pIsINF5LlssvzdVk9emWKzwNMEshOAH5xx275WcM34=";
  };

  nativeBuildInputs = [
    unzip
    installShellFiles
    makeWrapper
  ];

  dontBuild = true;
  # Keep the official executable byte-for-byte intact.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    installBin bin/gh
    wrapProgram $out/bin/gh --set-default GH_TELEMETRY false
    installManPage share/man/man1/*.1
    installShellCompletion --cmd gh \
      --bash <($out/bin/gh completion -s bash) \
      --fish <($out/bin/gh completion -s fish) \
      --zsh <($out/bin/gh completion -s zsh)
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "GitHub CLI tool";
    homepage = "https://cli.github.com/";
    changelog = "https://github.com/cli/cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "gh";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
