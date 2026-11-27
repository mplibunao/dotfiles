{
  lib,
  pkgs,
  nixpkgs-pre2611,
  ...
}:

{
  imports = [
    ./homebrew.nix
    ./defaults.nix
  ];

  nixpkgs = {
    hostPlatform = "aarch64-darwin";

    overlays = [
      # Native packages from the pre-26.11 pin: current unstable's cctools ld
      # crashes (Trace/BPT trap 5) on every local link step on this machine,
      # and the rev is too fresh for Hydra aarch64-darwin cache hits, so any
      # uncached native package fails to build. The old rev's builds are
      # already in this machine's store.
      # TODO: Remove once the cctools ld crash is fixed or Hydra caches the
      # pinned rev.
      (_final: prev: {
        inherit (nixpkgs-pre2611.legacyPackages.${prev.stdenv.hostPlatform.system})
          terminal-notifier
          whisper-cpp
          starship
          ;
      })
    ];

    # Allow specific unfree packages
    config.allowUnfreePredicate =
      pkg:
      builtins.elem (pkg.pname or (builtins.parseDrvName pkg.name).name) [
        "br"
        "bv"
        "terraform"
      ];
  };

  # Determinate Nix manages the Nix installation
  nix.enable = false;

  # User configuration
  users.users.mp = {
    name = "mp";
    home = "/Users/mp";
    shell = pkgs.fish;
  };

  # Primary user for Homebrew and other user-level operations
  system.primaryUser = "mp";

  # Add fish to acceptable shells
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];

  # set-environment replaces PATH in any shell started without
  # __NIX_DARWIN_SET_ENVIRONMENT_DONE, such as a bash whose stdin is a socket
  # (Node child processes, Turborepo tasks). Putting mise's shims first keeps
  # node and pnpm resolvable there, in the same order Home Manager's
  # sessionPath gives interactive shells.
  environment.systemPath = lib.mkBefore [ "$HOME/.local/share/mise/shims" ];

  # Fonts (Nerd Font patched versions)
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.fira-code
  ];

  # Home Manager integration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.mp = import ../../home/mp/darwin.nix;
  };

  # Show asterisks while typing the sudo password (instead of blank)
  security.sudo.extraConfig = ''
    Defaults pwfeedback
  '';

  # nix-darwin state version
  system.stateVersion = 4;
}
