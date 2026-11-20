{
  lib,
  stdenvNoCC,
  fetchurl,
  jdk_headless,
  makeWrapper,
}:

# Pinned to the Maven in WizyEMM's CI image (wizydev/maven-gcloud) so local
# builds match CI whatever nixpkgs ships. Maven 3.10.0 compiles
# prod-emm-public's Kotlin entities as final classes despite the all-open
# plugin, so build that project before changing the version.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "maven";
  version = "3.8.4";

  src = fetchurl {
    urls = [
      "https://archive.apache.org/dist/maven/maven-3/${finalAttrs.version}/binaries/apache-maven-${finalAttrs.version}-bin.tar.gz"
      "https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/${finalAttrs.version}/apache-maven-${finalAttrs.version}-bin.tar.gz"
    ];
    hash = "sha256-LNycUZQnuyD9wlvvWpBjt5Dkq9kw57FLTp9IY9b58Tw=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  # A JAVA_HOME set by the shell takes precedence; nixpkgs' JDK is the
  # fallback when it is unset.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/maven
    cp -r . $out/maven

    makeWrapper $out/maven/bin/mvn $out/bin/mvn \
      --set-default JAVA_HOME "${jdk_headless}"
    makeWrapper $out/maven/bin/mvnDebug $out/bin/mvnDebug \
      --set-default JAVA_HOME "${jdk_headless}"

    runHook postInstall
  '';

  meta = {
    description = "Build automation tool (used primarily for Java projects)";
    homepage = "https://maven.apache.org/";
    license = lib.licenses.asl20;
    mainProgram = "mvn";
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
    inherit (jdk_headless.meta) platforms;
  };
})
