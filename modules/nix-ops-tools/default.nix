{ config, pkgs, ... }:

let
  mkOOS = config.lib.file.mkOutOfStoreSymlink;
  # Scripts live in dotfiles/scripts/
  scriptsDir = "${config.home.homeDirectory}/Projects/personal/dotfiles/scripts";
in
{
  # Nix operational scripts - exposed as commands in ~/.local/bin
  #
  # Uses mkOutOfStoreSymlink so edits to scripts take effect immediately
  # without requiring a darwin-rebuild.
  #
  # Scripts:
  #   nix-locate                 - Find the dotfiles flake root
  #   nix-verify                 - Verification ladder runner
  #   nix-ops                    - Operational console
  #   cli-proxy-dashboard-setup  - Deploy main to the live usage dashboard
  #   claude-proxy-route         - Turn Claude Code's global CLIProxyAPI route on or off
  #
  # Lint/format tooling consumed by nix-verify Level 1.
  # The script keeps `command -v` guards so it stays portable before
  # activation, but these declarations guarantee the tools are present
  # in mp's Home Manager environment.
  home.packages = with pkgs; [
    deadnix
    statix
  ];

  home.file = {
    ".local/bin/nix-locate" = {
      source = mkOOS "${scriptsDir}/nix-locate";
      force = true;
    };
    ".local/bin/nix-verify" = {
      source = mkOOS "${scriptsDir}/nix-verify";
      force = true;
    };
    ".local/bin/nix-ops" = {
      source = mkOOS "${scriptsDir}/nix-ops";
      force = true;
    };
    ".local/bin/cli-proxy-dashboard-setup" = {
      source = mkOOS "${scriptsDir}/cli-proxy-dashboard-setup";
      force = true;
    };
    ".local/bin/claude-proxy-route" = {
      source = mkOOS "${scriptsDir}/claude-proxy-route";
      force = true;
    };
  };
}
