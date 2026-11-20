{
  config,
  lib,
  pkgs,
  ...
}:

# AeroSpace tiling window manager configuration
#
# Architecture: TOML as canonical authored config, Nix overlays dynamic content.
# See aerospace.toml in this directory for keybindings, gaps, layout settings.
#
# Ownership boundary (strictly enforced via assertions):
#   TOML owns: keybindings, key-mapping, gaps, layout, normalization, after-startup-command
#   Nix owns:  on-window-detected (float rules), exec (PATH/env)
#   HM owns:   start-at-login, after-login-command (overridden by launchd.enable)
#
# See also: dotfiles/keybinds/ for conflict detection across all keybind sources

let
  # Parse canonical TOML configuration
  tomlPath = ./aerospace.toml;

  parsed = builtins.tryEval (builtins.fromTOML (builtins.readFile tomlPath));
  baseConfig =
    if parsed.success then
      parsed.value
    else
      throw "AeroSpace TOML parse failed - check syntax in ${toString tomlPath}";

  # Workspace registry - single source of truth for workspace names
  # Path: from modules/aerospace/ up to data/
  workspacesFile = ../../data/workspaces.toml;
  inherit (builtins.fromTOML (builtins.readFile workspacesFile)) workspaces;

  # Strict ownership enforcement. These become Home Manager module assertions
  # because a lazy let-binding is not enough to force ownership checks in Nix.
  ownedKeyAssertions = [
    {
      key = "on-window-detected";
      message = "on-window-detected is Nix-owned, remove from TOML";
    }
    {
      key = "exec";
      message = "exec block is Nix-owned, remove from TOML";
    }
    {
      key = "start-at-login";
      message = "start-at-login is HM-overridden, remove from TOML";
    }
    {
      key = "after-login-command";
      message = "after-login-command is HM-overridden, remove from TOML";
    }
  ];

  # Apps that should float (system utilities + overlays)
  # Use: mdls -name kMDItemCFBundleIdentifier -r /Applications/App.app
  floatApps = [
    "com.apple.systempreferences" # System Settings
    "com.apple.finder" # Finder
    "com.apple.DiskUtility" # Disk Utility
    "com.apple.ActivityMonitor" # Activity Monitor
    "com.apple.Console" # Console
    "com.apple.keychainaccess" # Keychain Access
    "com.apple.Preview" # Preview (for dialogs)
    "com.apple.calculator" # Calculator
    "org.pqrs.Karabiner-Elements" # Karabiner
    "org.pqrs.Karabiner-EventViewer" # Karabiner Event Viewer
    "com.agilebits.onepassword7" # 1Password
    "com.keka.Keka" # Keka archive manager
    "com.apple.archiveutility" # Archive Utility
    "io.github.keycastr" # KeyCastr keystroke visualizer
  ];

  # Generate on-window-detected rules for float apps
  # CRITICAL: "app-id" must be quoted (hyphenated key)
  floatRules = map (appId: {
    "if" = {
      "app-id" = appId;
    };
    run = [ "layout floating" ];
  }) floatApps;

  # App-to-workspace assignments (only at startup to allow manual placement)
  # These use during-aerospace-startup = true so new windows during a session
  # stay on the current workspace - only initial arrangement is enforced.
  appAssignments = [
    # Terminal -> workspace 1
    {
      appId = "net.kovidgoyal.kitty";
      workspace = workspaces.terminal;
    }
    {
      appId = "com.github.wez.wezterm";
      workspace = workspaces.terminal;
    }

    # Browsers -> workspace 3
    {
      appId = "com.google.Chrome";
      workspace = workspaces.browser;
    }
    {
      appId = "company.thebrowser.Browser";
      workspace = workspaces.browser;
    } # Arc
    {
      appId = "org.mozilla.firefox";
      workspace = workspaces.browser;
    }

    # Repo Prompt -> workspace 4
    {
      appId = "com.pvncher.repoprompt";
      workspace = workspaces.repoPrompt;
    }

    # Slack -> workspace S
    {
      appId = "com.tinyspeck.slackmacgap";
      workspace = workspaces.slack;
    }

    # Discord -> workspace D
    {
      appId = "com.hnc.Discord";
      workspace = workspaces.discord;
    }

    # Codex -> workspace 6
    {
      appId = "com.openai.codex";
      workspace = workspaces.codex;
    }

    # Claude -> workspace 7
    {
      appId = "com.anthropic.claudefordesktop";
      workspace = workspaces.claude;
    }

    # Obsidian -> workspace O
    {
      appId = "md.obsidian";
      workspace = workspaces.obsidian;
    }

    # Music -> workspace M
    {
      appId = "com.spotify.client";
      workspace = workspaces.music;
    }
    {
      appId = "com.apple.Music";
      workspace = workspaces.music;
    }
  ];

  # Generate assignment rules
  assignmentRules = map (app: {
    "if" = {
      "app-id" = app.appId;
      "during-aerospace-startup" = true;
    };
    run = [ "move-node-to-workspace ${app.workspace}" ];
  }) appAssignments;

  # Path used by HM aerospace module for config file (with leading slash due to xdg keying)
  aerospaceConfigPath = "/.config/aerospace/aerospace.toml";

in
{
  assertions =
    (map (
      { key, message }:
      {
        # Use builtins.hasAttr because AeroSpace setting names include hyphens.
        assertion = !(builtins.hasAttr key baseConfig);
        inherit message;
      }
    ) ownedKeyAssertions)
    ++ [
      {
        # Ensure HM still manages the config at expected path. This guards against
        # HM changing XDG path keying and silently breaking our onChange override.
        assertion =
          (config.home.file.${aerospaceConfigPath}.source or null) != null
          || (config.home.file.${aerospaceConfigPath}.text or null) != null;
        message = ''
          Expected AeroSpace config at home.file."${aerospaceConfigPath}".
          Home Manager may have changed XDG path keying; update the onChange override.
        '';
      }
    ];

  # Borders helper (provides the `borders` CLI)
  # We prefer Nix for user-level tools instead of Homebrew taps.
  home.packages = [
    pkgs.jankyborders
    pkgs.coreutils # For timeout in onChange hook
  ];

  programs.aerospace = {
    enable = true;

    # Use the nixpkgs aerospace package
    # This provides both the CLI and the .app bundle for launchd integration
    package = pkgs.aerospace;

    # Launchd-managed auto-start
    # This overrides start-at-login and after-login-command in settings
    launchd.enable = true;
    launchd.keepAlive = false; # No respawn - user can quit for gaming

    # Merge TOML base config with Nix-owned overlays.
    settings = lib.recursiveUpdate baseConfig {
      # Nix-owned: Float rules for system apps + startup app assignments
      # IMPORTANT: AeroSpace stops at first match. Float rules must come first
      # so utility apps float regardless of startup assignment rules.
      on-window-detected = floatRules ++ assignmentRules;

      # Nix-owned: Environment for exec-* commands
      # Ensure Homebrew and Nix paths are available for launchd context
      # NOTE: PATH must be fully explicit - ${PATH} won't expand in launchd context
      exec = {
        inherit-env-vars = true;
        env-vars = {
          PATH = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/run/current-system/sw/bin:/etc/profiles/per-user/mp/bin";
        };
      };
    };
  };

  # Override HM's default onChange hook which fails if AeroSpace isn't running
  # The path uses leading slash due to how HM resolves xdg paths internally
  # Timeout prevents wedged IPC from blocking activation indefinitely
  home.file.${aerospaceConfigPath}.onChange = lib.mkForce ''
    if /usr/bin/pgrep -x "AeroSpace" >/dev/null 2>&1; then
      echo "Reloading AeroSpace config..." >&2
      ${pkgs.coreutils}/bin/timeout 5s ${lib.getExe config.programs.aerospace.package} reload-config || true
    fi
  '';
}
