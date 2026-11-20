# Executor MCP gateway Home Manager module
#
# Installs the pinned Executor release and runs its service as a user
# LaunchAgent, so every MCP client's `executor mcp` bridge reaches one
# long-lived owner of the upstream connections, OAuth logins, and approval
# rules.
#
# Usage in your darwin.nix:
#   mp.executor.enable = true;
#
# The deployment design, fixed values, upgrade order, and rollback live in the
# claude-toolkit plan docs/exec-plans/active/2026-09-23-executor-mcp-gateway.md.
# Executor's own `executor install` (LaunchAgent sh.executor.daemon, port 4789)
# must not be used alongside this module.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.executor;

  label = "com.mp.executor";
  home = config.home.homeDirectory;

  # Clients and the plist use the profile path rather than a store path, so a
  # package bump never leaves a client or launchd pointing at a collected path.
  program = "${config.home.profileDirectory}/bin/executor";

  # Pinned by the service and by every bridge (`--scope`) so a bridge-started
  # fallback service opens the same workspace as the launchd one. It sits
  # outside every project because Executor otherwise scopes to the working
  # directory.
  scopeDir = "${config.xdg.configHome}/executor-gateway/scope";

  logDir = "${config.xdg.stateHome}/executor";
  plistPath = "${home}/Library/LaunchAgents/${label}.plist";

  plistAttrs = {
    Label = label;
    ProgramArguments = [
      program
      "daemon"
      "run"
      "--foreground"
      "--port"
      "4788"
      "--hostname"
      "127.0.0.1"
    ];
    WorkingDirectory = scopeDir;
    # EXECUTOR_DATA_DIR and XDG_DATA_HOME stay unset so the service, the
    # bridges, and any fallback service agree on ~/.executor and
    # ~/.local/share/executor.
    EnvironmentVariables = {
      EXECUTOR_SCOPE_DIR = scopeDir;
      # Takes over from a bridge-started fallback service instead of refusing
      # to start while one holds the database.
      EXECUTOR_SUPERVISED = "1";
      EXECUTOR_DISABLE_ANALYTICS = "1";
      # The version is pinned here; the nudge would recommend `npm i -g`.
      EXECUTOR_DISABLE_UPDATE_CHECK = "1";
      HOME = home;
      USER = config.home.username;
      LOGNAME = config.home.username;
      PATH = lib.concatStringsSep ":" (
        lib.unique [
          cfg.nodeBin
          (builtins.dirOf cfg.dockerBin)
          "/usr/local/bin"
          "/usr/bin"
          "/bin"
        ]
      );
    };
    RunAtLoad = true;
    # A crash restarts the service; a deliberate stop stays stopped.
    KeepAlive.SuccessfulExit = false;
    ThrottleInterval = 30;
    # launchd reads the umask as a decimal integer: 63 is 0o077, so the
    # database, logs, and any files the service creates stay owner-only.
    Umask = 63;
    ExitTimeOut = 60;
    StandardOutPath = "${logDir}/executor.out.log";
    StandardErrorPath = "${logDir}/executor.err.log";
  };

  # Generated so paths are always XML-escaped; launchd silently ignores a
  # malformed plist at login.
  launchAgentPlist = pkgs.writeText "${label}.plist" (
    lib.generators.toPlist { escape = true; } plistAttrs
  );

  runtimeExecutable = "${cfg.package}/lib/executor/executor";
in
{
  options.mp.executor = {
    enable = lib.mkEnableOption "the Executor MCP gateway LaunchAgent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../../packages/executor { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../../packages/executor { }";
      description = "Executor release to install and run.";
    };

    nodeBin = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.local/share/mise/installs/node/24/bin";
      description = ''
        Absolute folder holding the `node` and `npx` the service's stdio
        sources use.

        launchd provides no login shell, and mise's shims resolve a version
        from the surrounding project, which a LaunchAgent does not have. The
        `24` element is mise's alias symlink, so patch upgrades are picked up
        without editing this.
      '';
    };

    dockerBin = lib.mkOption {
      type = lib.types.str;
      default = "/usr/local/bin/docker";
      description = "Absolute path to the Docker CLI the Terraform and Slack sources run.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.nodeBin;
        message = "mp.executor.nodeBin must be an absolute path; launchd resolves nothing.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.dockerBin;
        message = "mp.executor.dockerBin must be an absolute path; launchd resolves nothing.";
      }
    ];

    home = {
      packages = [ cfg.package ];

      file."Library/LaunchAgents/${label}.plist".source = launchAgentPlist;

      activation = {
        # Node and Docker live outside the Nix store, so evaluation cannot see
        # them. KeepAlive would turn a broken runtime into a respawn loop visible
        # only in a log; failing here stops the switch while someone is watching.
        # A stopped Docker Desktop is fine: only its CLI has to exist.
        #
        # Even `--version` writes a cache under the data folder, so the probe gets
        # a throwaway HOME; otherwise it would create ~/.executor with the
        # activation umask before the service does, and during dry runs too.
        checkExecutorRuntime = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
          _executor_probe="$(mktemp -d)"
          if ! HOME="$_executor_probe" \
            XDG_DATA_HOME="$_executor_probe/data" \
            EXECUTOR_DATA_DIR="$_executor_probe/executor" \
            EXECUTOR_DISABLE_ANALYTICS=1 \
            EXECUTOR_DISABLE_UPDATE_CHECK=1 \
            ${lib.escapeShellArg "${cfg.package}/bin/executor"} --version >/dev/null; then
            rm -rf "$_executor_probe"
            echo "mp.executor: ${cfg.package}/bin/executor --version failed." >&2
            exit 1
          fi
          rm -rf "$_executor_probe"
          if [ ! -x ${lib.escapeShellArg "${cfg.nodeBin}/npx"} ]; then
            echo "mp.executor: ${cfg.nodeBin}/npx is missing or not executable." >&2
            echo "  Install that Node with mise or set mp.executor.nodeBin, then switch again." >&2
            exit 1
          fi
          if [ ! -x ${lib.escapeShellArg cfg.dockerBin} ]; then
            echo "mp.executor: ${cfg.dockerBin} is missing or not executable." >&2
            echo "  Install Docker Desktop or set mp.executor.dockerBin, then switch again." >&2
            exit 1
          fi
        '';

        # launchd creates neither the working directory nor the log folder, and
        # either one missing fails the job at spawn.
        createExecutorDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD mkdir -p -m 0700 \
            ${lib.escapeShellArg (builtins.dirOf scopeDir)} \
            ${lib.escapeShellArg scopeDir} \
            ${lib.escapeShellArg logDir}
        '';

        # Loads the job when launchd does not have it and fails the switch if it
        # cannot be loaded or does not start. A running job is never restarted
        # here: a restart drops in-flight calls and pending browser approvals,
        # so it stays an explicit operator step. KeepAlive restarts only
        # failures, so a loaded job whose last exit was clean was stopped on
        # purpose and stays stopped; any other loaded job without a process is
        # failing and stops the switch.
        #
        # Runs after Home Manager's own LaunchAgent and file-change steps so a
        # failure here does not skip them.
        loadExecutorAgent =
          lib.hm.dag.entryAfter
            [
              "linkGeneration"
              "createExecutorDirs"
              "setupLaunchAgents"
              "onFilesChange"
            ]
            ''
              _executor_domain="gui/$(id -u)"
              _executor_target="$_executor_domain/${label}"
              _executor_state=""
              _executor_read_state() {
                _executor_state="$(/bin/launchctl print "$_executor_target" 2>/dev/null || true)"
              }
              # Top-level fields carry one tab of indentation; nested blocks
              # reuse names such as "state".
              _executor_field() {
                printf '%s\n' "$_executor_state" \
                  | /usr/bin/awk -F ' = ' -v key="$1" '$1 == "\t" key { print $2; exit }'
              }
              _executor_fail_not_running() {
                echo "mp.executor: ${label} $1 (last exit code: $(_executor_field 'last exit code'))." >&2
                echo "  Service logs: ${logDir}/" >&2
                echo "  After fixing the cause, run: launchctl kickstart -k $_executor_target" >&2
                exit 1
              }

              _executor_read_state
              if [ -z "$_executor_state" ]; then
                if [ -n "$DRY_RUN_CMD" ]; then
                  echo "would load: launchctl bootstrap $_executor_domain ${plistPath}"
                else
                  if ! /bin/launchctl bootstrap "$_executor_domain" ${lib.escapeShellArg plistPath}; then
                    echo "mp.executor: launchctl bootstrap failed; the service is not loaded." >&2
                    echo "  From MP's logged-in GUI session (not SSH), check and retry:" >&2
                    echo "    plutil -lint ${plistPath}" >&2
                    echo "    launchctl bootstrap $_executor_domain ${plistPath}" >&2
                    exit 1
                  fi
                  # RunAtLoad spawns at once, so a missing process after the
                  # wait means the spawn failed. A PID alone is not proof of a
                  # start: a process that exits on startup still has one
                  # briefly, and ThrottleInterval keeps launchd from replacing
                  # it within the settle window.
                  _executor_tries=0
                  while _executor_read_state && [ -z "$(_executor_field pid)" ]; do
                    _executor_tries=$((_executor_tries + 1))
                    if [ "$_executor_tries" -ge 20 ]; then
                      _executor_fail_not_running "was loaded but did not start within 10 seconds"
                    fi
                    sleep 0.5
                  done
                  _executor_pid="$(_executor_field pid)"
                  sleep 3
                  _executor_read_state
                  if [ "$(_executor_field pid)" != "$_executor_pid" ]; then
                    _executor_fail_not_running "started but exited within 3 seconds"
                  fi
                fi
              else
                _executor_pid="$(_executor_field pid)"
                if [ -z "$_executor_pid" ]; then
                  if [ "$(_executor_field 'last exit code')" = "0" ]; then
                    echo "executor: ${label} is loaded but stopped after a clean exit; leaving it stopped."
                    echo "  Start it with: launchctl kickstart $_executor_target"
                  else
                    _executor_fail_not_running "is loaded but not running"
                  fi
                else
                  _executor_stale=""
                  _executor_definition_changed=""
                  if [ -z "''${oldGenPath:-}" ] \
                    || ! cmp -s "$oldGenPath/home-files/Library/LaunchAgents/${label}.plist" ${launchAgentPlist}; then
                    _executor_stale="the LaunchAgent definition changed"
                    _executor_definition_changed=1
                  fi
                  _executor_cmd="$(/bin/ps -p "$_executor_pid" -o command= 2>/dev/null || true)"
                  case "$_executor_cmd" in
                    ${lib.escapeShellArg runtimeExecutable}" "*) ;;
                    *) _executor_stale="the running service is not this generation's executor" ;;
                  esac
                  if [ -n "$_executor_stale" ]; then
                    echo "executor: restart required, $_executor_stale."
                    echo "  Quit Executor clients first, then run:"
                    if [ -n "$_executor_definition_changed" ]; then
                      echo "  launchctl bootout $_executor_target"
                      echo "  launchctl bootstrap $_executor_domain ${plistPath}"
                    else
                      echo "  launchctl kickstart -k $_executor_target"
                    fi
                  fi
                fi
              fi
            '';
      };
    };
  };
}
