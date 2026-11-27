{ config, lib, ... }:

let
  # Conventional live checkout, relative to the home directory.
  dotfilesCheckoutRel = "Projects/personal/dotfiles";
in
{
  # Cross-platform Home Manager configuration

  # Absolute live checkout path. Modules that link out of the store take it as
  # a module argument instead of repeating the path.
  _module.args.dotfilesCheckoutDir = "${config.home.homeDirectory}/${dotfilesCheckoutRel}";

  home = {
    username = "mp";
    homeDirectory = "/Users/mp";

    # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
    stateVersion = "24.11";

    # Environment variables
    sessionVariables = {
      DOTFILES_DIR = "$HOME/${dotfilesCheckoutRel}";

      # FZF Catppuccin Mocha theme
      FZF_DEFAULT_OPTS = builtins.concatStringsSep " " [
        "--color=bg+:#414559,bg:#303446,spinner:#F2D5CF,hl:#E78284"
        "--color=fg:#C6D0F5,header:#E78284,info:#CA9EE6,pointer:#F2D5CF"
        "--color=marker:#BABBF1,fg+:#C6D0F5,prompt:#CA9EE6,hl+:#E78284"
        "--color=selected-bg:#51576D"
        "--color=border:#737994,label:#C6D0F5"
      ];

      # Docker BuildKit
      COMPOSE_DOCKER_CLI_BUILD = "1";
      DOCKER_BUILDKIT = "1";

      # GKE auth plugin
      USE_GKE_GCLOUD_AUTH_PLUGIN = "True";

      # rtk: hard-disable telemetry regardless of consent state (rtk-ai/rtk)
      RTK_TELEMETRY_DISABLED = "1";
    };

    # Additional PATH entries (order matters — first entry wins)
    sessionPath = lib.mkBefore [
      "$HOME/.local/share/mise/shims" # mise per-repo tool versions (non-interactive fallback)
      "$HOME/.local/bin"
    ];
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # XDG directories
  xdg.enable = true;
}
