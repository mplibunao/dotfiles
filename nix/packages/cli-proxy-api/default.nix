# CLIProxyAPI (https://github.com/router-for-me/CLIProxyAPI): local proxy for
# OAuth-backed Claude, Codex, and other CLI subscriptions.
#
# The flake's nixpkgs pin (2026-07-11) does not contain this package. Current
# nixpkgs-unstable does, at 8.0.48, but installing it would mean either moving
# the whole pin or compiling on m5-mbp, where cctools ld crashes on local links
# (hosts/m5-mbp/configuration.nix). v8.0.53 also wants Go 1.26. The official
# release tarball is the same approach as packages/executor and packages/gh:
# pinned bytes, no local link.
#
# `targetSystem` selects the upstream archive. Building the aarch64-darwin
# archive with a Linux stdenv only unpacks it, so a machine without a Darwin
# builder can still check the hash and the installed binary.
{
  lib,
  stdenvNoCC,
  fetchurl,
  targetSystem ? stdenvNoCC.hostPlatform.system,
}:

let
  sources = {
    aarch64-darwin = {
      suffix = "darwin_aarch64";
      hash = "sha256-JKkRapvkWenR31qXkuyhfwTAu4UFWE1AxbJVVl0HGG8=";
    };
    x86_64-linux = {
      suffix = "linux_amd64";
      hash = "sha256-lr3B7Bla3CO6rm6wQTqdzi/czwPA0/0pDpGqiBLipw0=";
    };
  };
  source = sources.${targetSystem} or (throw "cli-proxy-api: no release archive for ${targetSystem}");
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "cli-proxy-api";
  version = "8.0.53";

  src = fetchurl {
    url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${finalAttrs.version}/CLIProxyAPI_${finalAttrs.version}_${source.suffix}.tar.gz";
    hash = source.hash;
  };

  # The archive has no top-level directory. The executable stays byte-for-byte
  # intact: fixup would rewrite a Mach-O that only has to run on the Mac.
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    tar -xOf "$src" cli-proxy-api > "$out/bin/cli-proxy-api"
    chmod 0755 "$out/bin/cli-proxy-api"
    test -s "$out/bin/cli-proxy-api"
    runHook postInstall
  '';

  # No installCheck. The release binary is dynamically linked against the
  # host libc and is not patched, so the Nix sandbox cannot execute it
  # (exit 127). The non-empty file test above still runs. Version and login
  # flags are checked by running the Linux binary outside the sandbox.

  meta = {
    description =
      "Proxy that exposes OAuth-based AI CLI subscriptions over local OpenAI, Gemini, and Claude APIs"
      + lib.optionalString (targetSystem != stdenvNoCC.hostPlatform.system) " (${targetSystem} binary)";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    changelog = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # The derivation runs on the build platform. targetSystem chooses which
    # upstream archive is unpacked, including a Darwin binary unpacked on Linux.
    platforms = [ stdenvNoCC.hostPlatform.system ];
    mainProgram = "cli-proxy-api";
  };
})
