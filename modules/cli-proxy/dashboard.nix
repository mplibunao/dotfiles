# Usage dashboard Home Manager module.
#
# Runs Mark's private cli-proxy-dashboard as a user LaunchAgent, from its own
# checkout of main that cli-proxy-dashboard-setup deploys. Agents work in a
# different checkout, so switching branches there never changes the live
# dashboard. The repo is not a Nix package: it is private, and this flake
# cannot lock a git+ssh input or a pnpm dependency hash without Mark's GitHub
# SSH key. docs/architecture/runbooks/cli-proxy-api.md has the deploy steps.
#
# Feature switches such as SOONEST_RESET_ROUTING come from the checkout's
# config/production.env, which Bun loads with --env-file. A variable set in
# the plist would override that file, so the plist sets none of them.
#
# Usage in darwin.nix:
#   mp.cliProxyDashboard.enable = true;
#
# The management key comes from the same secrets file as CLIProxyAPI. The
# plist only carries the variable name. The wrapper assigns the value.
#
# The dashboard's own default for DATA_DIR is the relative folder "data"
# (src/server/config.ts). launchd's working directory is the checkout, so
# that default would write inside the repo. The agent sets DATA_DIR to
# xdg.dataHome/cli-proxy-dashboard and creates that directory mode 0700
# before the job starts. The listen port defaults to 8788; the surf gateway
# owns 8787. A warning remains if the two ports are set equal.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mp.cliProxyDashboard;
  key = import ./management-key.nix { inherit lib; };
  loadAgent = import ./launch-agent.nix { inherit lib; };

  label = "com.mp.cli-proxy-dashboard";
  home = config.home.homeDirectory;
  logDir = "${config.xdg.stateHome}/cli-proxy-dashboard";
  # xdg.dataHome is ~/.local/share under home.homeDirectory.
  dataDir = "${config.xdg.dataHome}/cli-proxy-dashboard";
  plistPath = "${home}/Library/LaunchAgents/${label}.plist";

  bunBin = lib.getExe pkgs.bun;

  launchScript = pkgs.writeShellScriptBin "cli-proxy-dashboard-launch" ''
    set -euo pipefail
    ${key.readCommand "_cpd_management_key" cfg.secretsFile}
    export ${cfg.managementKeyVariable}="$_cpd_management_key"
    unset _cpd_management_key
    export PATH=/usr/bin:/bin
    cd ${lib.escapeShellArg cfg.repoDir}
    exec ${lib.escapeShellArgs ([ bunBin ] ++ cfg.arguments)}
  '';

  plistAttrs = {
    Label = label;
    ProgramArguments = [ "${launchScript}/bin/cli-proxy-dashboard-launch" ];
    WorkingDirectory = cfg.repoDir;
    EnvironmentVariables = {
      HOME = home;
      USER = config.home.username;
      LOGNAME = config.home.username;
      PATH = "/usr/bin:/bin";
      NODE_ENV = "production";
      CPA_BASE_URL = cfg.baseUrl;
      DATA_DIR = dataDir;
      ${cfg.listenHostVariable} = cfg.host;
      ${cfg.listenPortVariable} = toString cfg.port;
    };
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    # 63 is 0o077. See api.nix.
    Umask = 63;
    ExitTimeOut = 20;
    StandardOutPath = "${logDir}/cli-proxy-dashboard.out.log";
    StandardErrorPath = "${logDir}/cli-proxy-dashboard.err.log";
  };

  launchAgentPlist = pkgs.writeText "${label}.plist" (
    lib.generators.toPlist { escape = true; } plistAttrs
  );

  surf = config.mp.surfOpenaiGateway;
in
{
  options.mp.cliProxyDashboard = {
    enable = lib.mkEnableOption "the CLIProxyAPI usage dashboard LaunchAgent";

    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/cli-proxy-dashboard/app";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/cli-proxy-dashboard/app"'';
      description = ''
        Absolute path of the live cli-proxy-dashboard checkout, which only
        follows main. Bun runs with this as its working directory.
        cli-proxy-dashboard-setup clones and deploys to the same default path.
      '';
    };

    arguments = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "--env-file=config/production.env"
        "src/server/index.ts"
      ];
      description = ''
        Arguments passed to Bun, run from repoDir. Naming an env file also
        stops Bun from auto-loading the checkout's ./.env.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address passed to the dashboard in listenHostVariable.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8788;
      description = ''
        Port passed to the dashboard in listenPortVariable.
        8787 belongs to mp.surfOpenaiGateway.
      '';
    };

    listenHostVariable = lib.mkOption {
      type = lib.types.str;
      default = "HOST";
      description = "Environment variable that receives the listen address.";
    };

    listenPortVariable = lib.mkOption {
      type = lib.types.str;
      default = "PORT";
      description = "Environment variable that receives the listen port.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://${config.mp.cliProxyApi.host}:${toString config.mp.cliProxyApi.port}";
      defaultText = lib.literalExpression ''"http://''${config.mp.cliProxyApi.host}:''${toString config.mp.cliProxyApi.port}"'';
      description = "Value of CPA_BASE_URL. Defaults to the CLIProxyAPI listener.";
    };

    managementKeyVariable = lib.mkOption {
      type = lib.types.str;
      default = "CPA_MANAGEMENT_KEY";
      description = ''
        Environment variable that receives the management key. Rename this if
        the dashboard reads a different name. The value still comes from
        secretsFile and is not stored in the plist.
      '';
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = config.mp.cliProxyApi.secretsFile;
      defaultText = lib.literalExpression "config.mp.cliProxyApi.secretsFile";
      description = "Mode-0600 file shared with mp.cliProxyApi.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.host == "127.0.0.1" || cfg.host == "localhost";
        message = "mp.cliProxyDashboard.host must be 127.0.0.1 or localhost.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.repoDir;
        message = "mp.cliProxyDashboard.repoDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" dataDir && !lib.hasInfix "/nix/store/" dataDir;
        message = "CLIProxy dashboard DATA_DIR must be an absolute path outside the Nix store.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.secretsFile && !lib.hasInfix "/nix/store/" cfg.secretsFile;
        message = "mp.cliProxyDashboard.secretsFile must be an absolute path outside the Nix store.";
      }
      {
        assertion = lib.match "[A-Za-z_][A-Za-z0-9_]*" cfg.managementKeyVariable != null;
        message = "mp.cliProxyDashboard.managementKeyVariable must be a shell variable name.";
      }
      {
        assertion = lib.match "[A-Za-z_][A-Za-z0-9_]*" cfg.listenHostVariable != null;
        message = "mp.cliProxyDashboard.listenHostVariable must be a shell variable name.";
      }
      {
        assertion = lib.match "[A-Za-z_][A-Za-z0-9_]*" cfg.listenPortVariable != null;
        message = "mp.cliProxyDashboard.listenPortVariable must be a shell variable name.";
      }
    ];

    warnings = lib.optional ((surf.enable or false) && surf.port == cfg.port) ''
      mp.cliProxyDashboard.port ${toString cfg.port} is the same as
      mp.surfOpenaiGateway.port. Both LaunchAgents cannot bind it.
      Move one before switching.
    '';

    home.file."Library/LaunchAgents/${label}.plist".source = launchAgentPlist;

    home.activation = {
      checkCliProxyDashboardRuntime = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        if [ ! -f ${lib.escapeShellArg "${cfg.repoDir}/package.json"} ]; then
          echo "mp.cliProxyDashboard: ${cfg.repoDir}/package.json is missing." >&2
          echo "  Run scripts/cli-proxy-dashboard-setup. See docs/architecture/runbooks/cli-proxy-api.md." >&2
          exit 1
        fi
        if [ ! -f ${lib.escapeShellArg "${cfg.repoDir}/src/server/index.ts"} ]; then
          echo "mp.cliProxyDashboard: ${cfg.repoDir}/src/server/index.ts is missing." >&2
          echo "  The checkout must be on the Bun server code. Update it, then switch again." >&2
          exit 1
        fi
        # Bun ignores a missing --env-file, so without this the dashboard would
        # start with every feature switch off.
        if [ ! -f ${lib.escapeShellArg "${cfg.repoDir}/config/production.env"} ]; then
          echo "mp.cliProxyDashboard: ${cfg.repoDir}/config/production.env is missing." >&2
          echo "  Run scripts/cli-proxy-dashboard-setup, then switch again." >&2
          exit 1
        fi
        if [ ! -d ${lib.escapeShellArg "${cfg.repoDir}/node_modules"} ]; then
          echo "mp.cliProxyDashboard: ${cfg.repoDir}/node_modules is missing." >&2
          echo "  Run scripts/cli-proxy-dashboard-setup, then switch again." >&2
          exit 1
        fi
        ${key.readCommand "_cpd_management_key" cfg.secretsFile}
        unset _cpd_management_key
      '';

      createCliProxyDashboardDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p -m 0700 \
          ${lib.escapeShellArg logDir} \
          ${lib.escapeShellArg dataDir}
        # mkdir -p does not tighten a directory that already exists.
        $DRY_RUN_CMD chmod 0700 ${lib.escapeShellArg dataDir}
      '';

      loadCliProxyDashboardAgent =
        lib.hm.dag.entryAfter
          [
            "linkGeneration"
            "createCliProxyDashboardDirs"
            "setupLaunchAgents"
            "onFilesChange"
          ]
          (
            loadAgent "cpd" {
              inherit label plistPath logDir;
              plistSource = launchAgentPlist;
            }
          );
    };
  };
}
