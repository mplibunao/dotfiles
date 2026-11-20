# surf OpenAI Gateway Home Manager Module
#
# Runs surf-cli's OpenAI-compatible gateway as a user LaunchAgent so the
# RepoPrompt oracle provider keeps answering across logins and reboots instead
# of only for as long as a terminal stays open.
#
# Usage in your darwin.nix:
#   mp.surfOpenaiGateway.enable = true;
#
# The plist mirrors the sample in surf-cli's packages/openai-gateway/README.md.
# That README owns the contract, including the arithmetic behind ExitTimeOut.
#
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.surfOpenaiGateway;

  label = "com.surf.openai-gateway";

  logDir = "${config.xdg.stateHome}/surf";
  stdoutLog = "${logDir}/openai-gateway.out.log";
  stderrLog = "${logDir}/openai-gateway.err.log";

  # A drain waits for every admitted completion, and one completion is not one
  # host operation: a suspect answer costs a query, then a recovery read, then
  # a nudge, each carrying its own backstop. launchd sends SIGKILL 20 seconds
  # after SIGTERM by default, which would cut off a running Pro query. At a
  # concurrency cap of 1 the bound is 5760 seconds, so 6000 clears it with
  # margin for a query that finishes at the deadline and still has to write its
  # response.
  #
  # The cap and the timeout are one setting in two places: raising the cap
  # without recomputing the timeout silently under-sizes the drain (at the
  # default cap of 8 the bound reaches 62460 seconds). Neither is exposed as an
  # option for that reason. To change either, recompute from `worstCaseDrainSec`
  # in surf-cli's src/apps/openai-gateway-config.ts and change both together.
  maxInflight = "1";
  exitTimeOutSeconds = 6000;

  # launchd reads the umask as a decimal integer. 63 is 0o77, so the log files
  # launchd creates are reachable only by this user, matching the 0700 on the
  # directory holding them.
  logUmask = 63;

  plistAttrs = {
    Label = label;
    ProgramArguments = [
      cfg.nodeBin
      cfg.entrypoint
      "serve"
      "--host"
      "127.0.0.1"
      "--port"
      (toString cfg.port)
      "--profile"
      cfg.profile
    ];
    EnvironmentVariables = {
      SURF_OPENAI_GATEWAY_MAX_INFLIGHT = maxInflight;
      PATH = "${builtins.dirOf cfg.nodeBin}:/usr/bin:/bin";
    };
    RunAtLoad = true;
    KeepAlive = true;
    ExitTimeOut = exitTimeOutSeconds;
    Umask = logUmask;
    StandardOutPath = stdoutLog;
    StandardErrorPath = stderrLog;
  };

  # Generated rather than hand-written: a profile address or path carrying an
  # ampersand or an angle bracket would produce XML that parses as garbage, and
  # launchd answers malformed plists by ignoring the job at login without
  # saying so.
  launchAgentPlist = pkgs.writeText "${label}.plist" (
    lib.generators.toPlist { escape = true; } plistAttrs
  );

in
{
  options.mp.surfOpenaiGateway = {
    enable = lib.mkEnableOption "the surf OpenAI gateway LaunchAgent";

    nodeBin = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/mise/installs/node/24/bin/node";
      description = ''
        Absolute path to the Node interpreter the agent runs.

        launchd starts jobs without a login shell, so the interpreter has to be
        named outright. This points at the mise install rather than at any shim:
        both mise's shims and ~/.vite-plus/bin/node resolve a version from the
        surrounding project, and a LaunchAgent has no project around it. The
        `24` element is mise's alias symlink, so patch upgrades are picked up
        without editing this.
      '';
    };

    entrypoint = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/references/ai/surf-cli/packages/surf-cli/dist-native/apps/openai-gateway.js";
      description = ''
        Absolute path to the assembled gateway entrypoint. This is the flat
        dist-native tree, which is the build output meant to run standalone.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Loopback port the gateway listens on.";
    };

    profile = lib.mkOption {
      type = lib.types.str;
      default = "mark.paolo.libunao@gmail.com";
      description = "ChatGPT browser profile the gateway drives.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.nodeBin;
        message = "mp.surfOpenaiGateway.nodeBin must be an absolute path; launchd resolves nothing.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.entrypoint;
        message = "mp.surfOpenaiGateway.entrypoint must be an absolute path; launchd resolves nothing.";
      }
    ];

    home.activation = {
      # Both paths live outside the Nix store, so evaluation can say nothing
      # about whether they exist. KeepAlive restarts a job that exits, so a
      # missing interpreter or entrypoint becomes an endless respawn loop that
      # surfaces only in a log nobody is watching. Failing here stops the
      # switch while the person who ran it is still looking at the terminal.
      checkSurfGatewayRuntime = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if [ ! -x ${lib.escapeShellArg cfg.nodeBin} ]; then
          echo "mp.surfOpenaiGateway: ${cfg.nodeBin} is missing or not executable." >&2
          echo "  The LaunchAgent would respawn forever. Set mp.surfOpenaiGateway.nodeBin" >&2
          echo "  to an installed Node, or install that version, then switch again." >&2
          exit 1
        fi
        if [ ! -r ${lib.escapeShellArg cfg.entrypoint} ]; then
          echo "mp.surfOpenaiGateway: ${cfg.entrypoint} is missing or unreadable." >&2
          echo "  Build it in surf-cli with 'pnpm run build:native', or set" >&2
          echo "  mp.surfOpenaiGateway.entrypoint, then switch again." >&2
          exit 1
        fi
      '';

      # launchd creates the log files but not the directory holding them, and a
      # missing directory fails the job at spawn rather than at first write.
      #
      # Nothing rotates these. The gateway writes one short JSON line per
      # request, so the files grow slowly enough to leave unmanaged; if that
      # changes, add rotation rather than truncating them out from under a
      # running job.
      createSurfGatewayLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p -m 0700 ${lib.escapeShellArg logDir}
      '';
    };

    home.file."Library/LaunchAgents/${label}.plist" = {
      source = launchAgentPlist;
    };
  };
}
