# CLIProxyAPI Home Manager module.
#
# Installs the pinned release and runs it as a user LaunchAgent on
# 127.0.0.1:8317. OAuth logins stay in CLIProxyAPI's own directory,
# ~/.cli-proxy-api, which this module creates but does not otherwise manage,
# so they survive rebuilds.
#
# Usage in darwin.nix:
#   mp.cliProxyApi.enable = true;
#
# The management key is read at start from a mode-0600 file outside the
# store. It is not written into config.yaml: a plaintext management.secret-key
# is bcrypt-hashed and written back into that file, and a store path is
# world-readable and immutable. The file is passed to the process as
# MANAGEMENT_PASSWORD. allow-remote stays false, and the listener is loopback,
# so that variable does not open the management API off-machine.
#
# Client keys are access.api-keys in v8.0.53. There is no environment
# variable for them. The store config stays free of keys. The launch wrapper
# copies it to a mode-0600 runtime file and appends the client key from
# CLIPROXY_CLIENT_KEY.
#
# A second, one-shot LaunchAgent (com.mp.cli-proxy-env) publishes the GUI
# session's environment with `launchctl setenv` and `unsetenv`. It reads the
# client key from the same secrets file and follows the route setting
# ~/.local/state/cli-proxy-api/claude-route, which claude-proxy-route writes
# (on or off; a missing file means on). On, it points Claude Code at the
# proxy: ANTHROPIC_BASE_URL, plus the client key as ANTHROPIC_AUTH_TOKEN. Off,
# it unsets both. Either way it publishes CLIPROXY_CLIENT_KEY, which
# OpenCode's DeepSeek provider reads. It does not route Codex. Afterwards, a
# macOS notification names each watched app that started with other values,
# such as an app macOS reopened at login before the agent ran. The publisher
# is scripts/cli-proxy-env-launch. launch-agent.nix is not used for this
# agent: that helper fails a job that exits, and this one is meant to. The
# key is never written into this module's strings.
#
# Login, the secret file, and log checks: nix/docs/runbooks/cli-proxy-api.md.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.cliProxyApi;
  key = import ./management-key.nix { inherit lib; };
  loadAgent = import ./launch-agent.nix { inherit lib; };

  label = "com.mp.cli-proxy-api";
  home = config.home.homeDirectory;
  logDir = "${config.xdg.stateHome}/cli-proxy-api";
  configDir = "${config.xdg.configHome}/cli-proxy-api";
  # Regenerated on every start. Not the store symlink. Mode 0600.
  runtimeConfig = "${logDir}/runtime-config.yaml";
  authDir = "${home}/.cli-proxy-api";
  plistPath = "${home}/Library/LaunchAgents/${label}.plist";
  runtimeScript = pkgs.writeShellScriptBin "cli-proxy-runtime-config" (
    builtins.readFile ../../scripts/cli-proxy-runtime-config
  );

  # v8 layout. secret-key is intentionally empty. Client API keys are not
  # declared here; putting one in this string would copy it into the store.
  # The wrapper appends access.api-keys onto a private copy. Do not add an
  # access: section here or that append refuses to run.
  #
  # upstream.claude.header-defaults is the Claude Code fingerprint the proxy
  # sends upstream. v8.0.53's built-in default is Claude Code 2.1.280, and
  # Anthropic refuses newer models, such as Fable 5.2, for clients older than
  # their minimum version. The proxy passes a client's own fingerprint through
  # only when its version, package version and runtime version all equal these
  # values, and sends these values for every other client. They were measured
  # from Claude Code 2.1.321; the runbook says how to measure a newer release.
  configText = ''
    config-version: 8
    server:
      host: "${cfg.host}"
      port: ${toString cfg.port}
    management:
      allow-remote: false
      secret-key: ""
    oauth:
      auth-dir: "~/.cli-proxy-api"
    observability:
      usage:
        usage-statistics-enabled: true
        redis-usage-queue-retention-seconds: 3600
    routing:
      session-affinity: true
      session-affinity-ttl: 1h
      session-affinity-rebind-on: quota
    upstream:
      claude:
        header-defaults:
          user-agent: "claude-cli/2.1.321 (external, cli)"
          package-version: "0.128.0"
          runtime-version: "v26.12.1"
  '';

  configFile = pkgs.writeText "cli-proxy-api-config.yaml" configText;

  launchScript = pkgs.writeShellScriptBin "cli-proxy-api-launch" ''
    set +x
    set -euo pipefail
    ${key.readCommand "_cpa_management_key" cfg.secretsFile}
    export MANAGEMENT_PASSWORD="$_cpa_management_key"
    unset _cpa_management_key
    ${runtimeScript}/bin/cli-proxy-runtime-config \
      --secrets ${lib.escapeShellArg cfg.secretsFile} \
      --template ${lib.escapeShellArg configFile} \
      --out ${lib.escapeShellArg runtimeConfig}
    exec ${lib.escapeShellArg "${cfg.package}/bin/cli-proxy-api"} --config ${lib.escapeShellArg runtimeConfig}
  '';

  envLabel = "com.mp.cli-proxy-env";
  envPublisher = pkgs.writeShellScriptBin "cli-proxy-env-launch" (
    builtins.readFile ../../scripts/cli-proxy-env-launch
  );
  # Process names of apps whose Claude sessions take the route from the
  # environment the app started with. RepoPromptDebug is RepoPrompt CE's Debug
  # build. claude-launch, which T3 Code runs, reads the route setting itself.
  watchedProcesses = [
    "RepoPrompt"
    "RepoPromptDebug"
    "kitty"
  ];
  watchArgs = lib.concatMapStringsSep " " (
    name: "--watch-process ${lib.escapeShellArg name}"
  ) watchedProcesses;
  # readKeyCommand stays the only reader of the secrets file. It runs `exit 1`
  # on any failure, which inside the command substitution ends only that
  # subshell, so the publisher still runs without CPA_CLIENT_KEY and can apply
  # an `off` route. The reader's messages go to the agent's error log.
  envScript = pkgs.writeShellScriptBin "cli-proxy-env-launch" ''
    set +x
    set -euo pipefail
    unset CPA_CLIENT_KEY
    if _cpa_client_key=$(
      ${key.readKeyCommand "CLIPROXY_CLIENT_KEY" "_cpa_client_key" cfg.secretsFile}
      printf '%s' "$_cpa_client_key"
    ); then
      export CPA_CLIENT_KEY="$_cpa_client_key"
    fi
    unset _cpa_client_key
    exec ${envPublisher}/bin/cli-proxy-env-launch \
      --route-file ${lib.escapeShellArg "${logDir}/claude-route"} \
      --base-url ${lib.escapeShellArg "http://${cfg.host}:${toString cfg.port}"} \
      ${watchArgs}
  '';

  plistAttrs = {
    Label = label;
    ProgramArguments = [ "${launchScript}/bin/cli-proxy-api-launch" ];
    WorkingDirectory = configDir;
    EnvironmentVariables = {
      HOME = home;
      USER = config.home.username;
      LOGNAME = config.home.username;
      PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      # Changes when the declarative config changes, so activation notices
      # that a running job is stale. Not a secret.
      CLIPROXY_CONFIG_ID = builtins.hashString "sha256" configText;
    };
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    # launchd reads the umask as a decimal integer. 63 is 0o077, so files the
    # service creates are owner-only. launchd's own log files honor it too.
    Umask = 63;
    ExitTimeOut = 20;
    StandardOutPath = "${logDir}/cli-proxy-api.out.log";
    StandardErrorPath = "${logDir}/cli-proxy-api.err.log";
  };

  launchAgentPlist = pkgs.writeText "${label}.plist" (
    lib.generators.toPlist { escape = true; } plistAttrs
  );
in
{
  options.mp.cliProxyApi = {
    enable = lib.mkEnableOption "the CLIProxyAPI LaunchAgent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../packages/cli-proxy-api { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../packages/cli-proxy-api { }";
      description = "CLIProxyAPI release to install and run.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the proxy binds. Loopback only.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8317;
      description = "Port the proxy binds.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${configDir}/secrets.env";
      defaultText = lib.literalExpression ''"''${config.xdg.configHome}/cli-proxy-api/secrets.env"'';
      description = ''
        Absolute path of the mode-0600 file that holds CLIPROXY_MANAGEMENT_KEY
        and CLIPROXY_CLIENT_KEY. Home Manager does not write this file. The
        dashboard module reads the management key from it too.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host == "127.0.0.1" || cfg.host == "localhost";
        message = "mp.cliProxyApi.host must be 127.0.0.1 or localhost.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.secretsFile && !lib.hasInfix "/nix/store/" cfg.secretsFile;
        message = "mp.cliProxyApi.secretsFile must be an absolute path outside the Nix store.";
      }
      # claude-proxy-route and claude-launch run from working checkouts and
      # hardcode the route setting's path and the proxy URL, so the env agent
      # must read and publish the same values.
      {
        assertion = logDir == "${home}/.local/state/cli-proxy-api";
        message = "mp.cliProxyApi: claude-proxy-route and claude-launch read the route setting from ~/.local/state/cli-proxy-api, so xdg.stateHome must be ~/.local/state.";
      }
      {
        assertion = cfg.host == "127.0.0.1" && cfg.port == 8317;
        message = "mp.cliProxyApi: claude-proxy-route and claude-launch expect the proxy at http://127.0.0.1:8317, so host must be 127.0.0.1 and port 8317.";
      }
    ];

    home.packages = [ cfg.package ];

    # Home Manager's setupLaunchAgents bootstraps this on switch (which runs
    # it once) and removes it if the option goes away. RunAtLoad runs it again
    # at every login. KeepAlive stays off: it sets the variables and exits.
    # claude-proxy-route re-runs it with `launchctl kickstart`.
    # ThrottleInterval = 1 keeps launchd from holding a second kickstart in a
    # row for its default 10 seconds.
    launchd.agents.cli-proxy-env = {
      enable = true;
      config = {
        Label = envLabel;
        ProgramArguments = [ "${envScript}/bin/cli-proxy-env-launch" ];
        RunAtLoad = true;
        ThrottleInterval = 1;
        Umask = 63;
        StandardOutPath = "${logDir}/cli-proxy-env.out.log";
        StandardErrorPath = "${logDir}/cli-proxy-env.err.log";
      };
    };

    xdg.configFile."cli-proxy-api/config.yaml".source = configFile;

    home.file."Library/LaunchAgents/${label}.plist".source = launchAgentPlist;

    home.activation = {
      checkCliProxyApiRuntime = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        _cpa_probe="$(mktemp -d)"
        if ! HOME="$_cpa_probe" ${lib.escapeShellArg "${cfg.package}/bin/cli-proxy-api"} --help >/dev/null; then
          rm -rf "$_cpa_probe"
          echo "mp.cliProxyApi: ${cfg.package}/bin/cli-proxy-api --help failed." >&2
          exit 1
        fi
        rm -rf "$_cpa_probe"
        ${key.readCommand "_cpa_management_key" cfg.secretsFile}
        unset _cpa_management_key
        ${key.readKeyCommand "CLIPROXY_CLIENT_KEY" "_cpa_client_key" cfg.secretsFile}
        unset _cpa_client_key
      '';

      # Before setupLaunchAgents so the env agent's log directory, which also
      # holds the route setting, exists when launchd bootstraps it.
      createCliProxyApiDirs = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p -m 0700 \
          ${lib.escapeShellArg logDir} \
          ${lib.escapeShellArg configDir} \
          ${lib.escapeShellArg authDir}
        $DRY_RUN_CMD chmod 0700 ${lib.escapeShellArg authDir}
      '';

      loadCliProxyApiAgent =
        lib.hm.dag.entryAfter
          [
            "linkGeneration"
            "createCliProxyApiDirs"
            "setupLaunchAgents"
            "onFilesChange"
          ]
          (
            loadAgent "cpa" {
              inherit label plistPath logDir;
              plistSource = launchAgentPlist;
            }
          );
    };
  };
}
