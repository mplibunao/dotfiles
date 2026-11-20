# Executor (https://github.com/UsefulSoftwareCo/executor): local MCP gateway.
#
# Repackages the upstream macOS release rather than building from source. The
# release executable is a Bun-compiled binary that loads libsql.node,
# keyring.node, workerd, the WASM modules, and worker-bundler/ from the folder
# holding its real path, so the whole archive stays together under lib/.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  runtimeShell,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "executor";
  version = "1.6.10";

  src = fetchurl {
    url = "https://github.com/UsefulSoftwareCo/executor/releases/download/v${finalAttrs.version}/executor-darwin-arm64.zip";
    hash = "sha256-Zt5c68vBfFPX/CwqJWqV5snHB90SkK6qNLk6rEZTixU=";
  };

  nativeBuildInputs = [ unzip ];

  # The archive has no top-level folder, so it is extracted straight into place.
  dontUnpack = true;

  # Fixup would strip the executables, which truncates the application bundle
  # Bun appends to the binary and invalidates the upstream code signatures.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/executor" "$out/bin"
    unzip -q "$src" -d "$out/lib/executor"

    # exec keeps the PID launchd starts, which Executor records in server.json,
    # and leaves process.execPath inside lib/executor next to the runtime files.
    cat >"$out/bin/executor" <<EOF
    #!${runtimeShell}
    exec "$out/lib/executor/executor" "\$@"
    EOF
    chmod 0755 "$out/bin/executor"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for f in executor workerd libsql.node keyring.node emscripten-module.wasm \
      onepassword-core_bg.wasm mcp-app.html worker-bundler/dist/index.js; do
      [ -e "$out/lib/executor/$f" ] || { echo "missing runtime file: $f" >&2; exit 1; }
    done

    # Isolated folders keep the check from reading or creating real state.
    check_root="$(mktemp -d)"
    reported="$(
      HOME="$check_root" \
        XDG_DATA_HOME="$check_root/data" \
        EXECUTOR_DATA_DIR="$check_root/executor" \
        EXECUTOR_SCOPE_DIR="$check_root/scope" \
        EXECUTOR_DISABLE_ANALYTICS=1 \
        EXECUTOR_DISABLE_UPDATE_CHECK=1 \
        "$out/bin/executor" --version
    )"
    echo "$reported" | grep -Fq "${finalAttrs.version}" \
      || { echo "unexpected version output: $reported" >&2; exit 1; }

    runHook postInstallCheck
  '';

  meta = {
    description = "Local MCP gateway that serves many upstream tool sources through one connection";
    homepage = "https://github.com/UsefulSoftwareCo/executor";
    changelog = "https://github.com/UsefulSoftwareCo/executor/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
    mainProgram = "executor";
  };
})
