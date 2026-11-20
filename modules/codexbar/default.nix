# CodexBar RepoPrompt profile-home module
#
# Usage in your darwin.nix:
#   mp.codexbar.enable = true;
#
# CodexBar aggregates local Codex JSONL sessions, but RepoPrompt CE runs its
# bundled Codex against an isolated CODEX_HOME, so those sessions are invisible
# to CodexBar's default scan. Registering that home in the Codex provider's
# codexProfileHomePaths array fixes the input boundary.
#
# This module owns that single array member and nothing else. CodexBar keeps
# ownership of the rest of its config — accounts, credentials, provider state,
# preferences — which is why the file is neither store-managed (ADR-019's
# default) nor tracked in git. ADR-022 records the full boundary; operational
# commands live in docs/architecture/gui-apps.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.codexbar;

  # Homebrew installs the codexbar CLI under the Apple Silicon prefix (ADR-005),
  # and the helper's process/version probes need macOS' own launchctl, pgrep,
  # ps, and defaults. PATH is set outright rather than prefixed so the helper
  # behaves identically under activation, which runs with a minimal
  # environment, and in an interactive shell.
  systemBinPath = "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin";

  runtimePath =
    lib.makeBinPath [
      pkgs.bash
      pkgs.jq
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
    ]
    + ":${systemBinPath}";

  # Replaces the helper's `/usr/bin/env bash` shebang and pins its PATH. An
  # activation-time helper that rewrites a private JSON file must not resolve
  # jq from whatever environment the caller happens to expose.
  prologue = pkgs.writeText "codexbar-config-prologue" ''
    #!${pkgs.bash}/bin/bash
    export PATH=${lib.escapeShellArg runtimePath}
  '';

  # A single self-contained script. `exec -a` cannot survive a shebang re-exec,
  # so wrapping the helper instead of rewriting its prologue would make it print
  # its own internal `.codexbar-config-wrapped` path as the supervised command
  # on deferral, and that path runs without the pinned PATH.
  codexbarConfig =
    pkgs.runCommandLocal "codexbar-config"
      {
        meta.mainProgram = "codexbar-config";
      }
      ''
        src=${../../scripts/codexbar-config}
        # The prologue takes over line 1, so a changed shebang has to fail the
        # build instead of silently landing as a stray directive mid-script.
        head -n 1 "$src" | grep -qx '#!/usr/bin/env bash' \
          || { echo "codexbar-config: unexpected shebang in $src" >&2; exit 1; }
        mkdir -p "$out/bin"
        cat ${prologue} >"$out/bin/codexbar-config"
        tail -n +2 "$src" >>"$out/bin/codexbar-config"
        chmod 0755 "$out/bin/codexbar-config"

        artifact="$out/bin/codexbar-config"
        head -n 1 "$artifact" | grep -Fqx ${lib.escapeShellArg "#!${pkgs.bash}/bin/bash"} \
          || { echo "codexbar-config: packaged artifact has an unexpected shebang" >&2; exit 1; }
        sed -n '2p' "$artifact" | grep -Fqx ${lib.escapeShellArg "export PATH=${lib.escapeShellArg runtimePath}"} \
          || { echo "codexbar-config: packaged artifact has an unexpected PATH prologue" >&2; exit 1; }
        ${pkgs.bash}/bin/bash -n "$artifact"
      '';

  helper = lib.getExe codexbarConfig;

  # The helper keeps its reconciliation lock under
  # ~/.local/state/codexbar-config, so backups sit beside it instead of
  # following xdg.stateHome, which would split the two if that ever moves.
  backupDir = "${config.home.homeDirectory}/.local/state/codexbar-config/backups";

  checkArgs = [
    "--config"
    cfg.configPath
    "--profile-home"
    cfg.profileHome
  ];
  writeArgs = checkArgs ++ [
    "--backup-dir"
    backupDir
  ];
  quoted = args: lib.concatMapStringsSep " " lib.escapeShellArg args;
in
{
  options.mp.codexbar = {
    enable = lib.mkEnableOption "reconciliation of CodexBar's RepoPrompt profile home";

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/codexbar/config.json";
      description = ''
        Absolute path to CodexBar's effective writable config.

        Home Manager's evaluated XDG config path is encoded rather than
        rediscovered on every activation. A stray file appearing in a
        higher-precedence location must not silently redirect ownership. The
        helper fails closed when it finds such an override instead of writing a
        shadowed file.
      '';
    };

    profileHome = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Library/Application Support/RepoPrompt CE/Codex/Release/home";
      description = ''
        Absolute CODEX_HOME that RepoPrompt CE hands its bundled Codex, and the
        one array member this module owns.

        Compared literally against existing entries, so it must match the path
        RepoPrompt CE actually uses. If a future release moves it, reinspect
        RepoPrompt CE's runtime authority rather than broadening the match.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.configPath;
        message = "mp.codexbar.configPath must be absolute; the helper refuses a relative target.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.profileHome;
        message = "mp.codexbar.profileHome must be absolute; the helper refuses a relative target.";
      }
      {
        # The merge reserializes the whole document, and jq below 1.7 degrades
        # untouched large integers and high-precision decimals in CodexBar's
        # own values while doing so.
        assertion = lib.versionAtLeast pkgs.jq.version "1.7";
        message = "mp.codexbar requires jq >= 1.7 for numeric fidelity; nixpkgs currently provides ${pkgs.jq.version}.";
      }
    ];

    # Exposed as a command so the supervised reconcile, removal, and post-update
    # revalidation documented in docs/architecture/gui-apps.md have a stable invocation.
    home.packages = [ codexbarConfig ];

    # Runs after the link generation so the reconciliation happens once the rest
    # of the generation is in place. nix-darwin executes this as mp even when the
    # outer switch used sudo; the helper refuses to rewrite the file or create
    # backups as root rather than producing root-owned private state.
    home.activation.reconcileCodexbarProfileHome = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -n "$DRY_RUN_CMD" ]; then
        if ! ${helper} check ${quoted checkArgs}; then
          echo "mp.codexbar: read-only check failed (see the error above)." >&2
          echo "  Nothing was written. Resolve it, or set mp.codexbar.enable = false," >&2
          echo "  before switching." >&2
          exit 1
        fi
      else
        # Deferral keeps a running CodexBar from racing an app-side save without
        # failing a switch that has nothing to do with CodexBar; the helper
        # prints the supervised command to run after quitting it.
        if ! ${helper} reconcile ${quoted writeArgs} --defer-if-running; then
          echo "mp.codexbar: reconciliation refused to write; the CodexBar config is unchanged." >&2
          echo "  A missing config means CodexBar has never run on this machine — launch it" >&2
          echo "  once so it writes its own skeleton, then switch again." >&2
          echo "  See docs/architecture/gui-apps.md for the recovery and removal commands." >&2
          exit 1
        fi
      fi
    '';
  };
}
