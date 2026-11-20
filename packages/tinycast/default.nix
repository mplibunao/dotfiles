{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tinycast";
  version = "0.12.8";

  src = fetchurl {
    url = "https://github.com/abue-ammar/tinycast/releases/download/v${finalAttrs.version}/Tinycast-${finalAttrs.version}.zip";
    hash = "sha256-1SV0lcAX23p8V3rIG5e7uxxr+ThFLUkPFFUZmEjbP1c=";
  };

  nativeBuildInputs = [ unzip ];
  dontUnpack = true;

  # Preserve the upstream app's code signature when copying its native binary.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    unzip -q "$src" -d "$out/Applications"
    test -x "$out/Applications/Tinycast.app/Contents/MacOS/Tinycast"
    runHook postInstall
  '';

  meta = {
    description = "Native macOS launcher with Raycast extension support";
    homepage = "https://github.com/abue-ammar/tinycast";
    changelog = "https://github.com/abue-ammar/tinycast/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
