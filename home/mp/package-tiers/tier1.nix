{
  opencode,
  pkgs,
  ...
}:

let
  openCodePackage = pkgs.callPackage ../../../packages/opencode { opencodeFlake = opencode; };
in
{
  home.packages = with pkgs; [
    # Modern CLI replacements
    # bat configured via modules/bat.nix
    lsd # ls replacement with icons
    fd # find replacement
    ripgrep # grep replacement
    fzf # fuzzy finder
    zoxide # smart cd
    bottom # top replacement (system monitor)
    smartmontools # SMART/NVMe disk health diagnostics (smartctl)
    duf # df replacement (disk usage)
    ncdu # du replacement (disk usage analyzer)
    fastfetch # neofetch replacement (system info)

    # Core utilities
    tree
    jq
    yq
    wget
    tmux
    coreutils
    gnused
    gawk
    rsync # File sync (used by claude-toolkit skill sync)
    terminal-notifier # macOS notifications (used by ccctl)
    gnupg # GPG signing/verification; lets mise verify Node download signatures (not just checksums)

    # Development
    (pkgs.callPackage ../../../packages/gh { }) # GitHub CLI
    lazygit # Git TUI
    just # Command runner (used by nvim-lazy harness)

    # Media
    ffmpeg # Video/audio processing

    # GUI apps provided as Nix packages
    (pkgs.callPackage ../../../packages/tinycast { }) # Primary launcher

    # LLM Tools
    openCodePackage
  ];
}
