# Homebrew casks and brews managed by nix-darwin (brews via ADR-016 exception)
# Homebrew must be installed first: https://brew.sh
{ config, ... }:

let
  # nix-darwin runs `brew bundle` as this user during system activation.
  brewUser = config.homebrew.user;
  brewHome = config.users.users.${brewUser}.home;
in
{
  homebrew = {
    enable = true;

    # Remove undeclared brews/casks on activation (for casks: uninstall without zap; for brews: removes the formula)
    onActivation = {
      autoUpdate = false; # Don't auto-update on rebuild
      cleanup = "uninstall"; # For casks: preserves app data (vs zap). Also removes undeclared brews. See ADR-016
      upgrade = false; # Don't auto-upgrade
    };

    # Homebrew taps
    taps = [
      "gildas/tap" # Bitbucket CLI
      "jazzyalex/agent-sessions" # Agent Sessions multi-agent transcript browser
      "repoprompt/repoprompt-ce" # RepoPrompt CE cask
      "steipete/tap" # CodexBar
      "xykong/tap" # Flux Markdown
    ];

    # CLI tools (prefer Nix when possible; exceptions via ADR-016)
    brews = [
      # gildas/tap formulae
      "gildas/tap/bitbucket-cli" # Bitbucket CLI (bb command)

      # Unqualified formulae
      "mole" # macOS disk analyzer; tw93/Mole is unavailable in the pinned nixpkgs
      "watchman" # File watcher Jest uses in the work web projects
      "rtk" # CLI proxy that compresses LLM-bound command output (60-90% token savings)
      "sqlite" # Homebrew libsqlite3.dylib for gno sqlite-vec on macOS
      "swiftlint" # Swift linter for RepoPrompt CE; its format tooling installs it through Homebrew
    ];

    # GUI applications
    casks = [
      # Tier 1: Development
      "android-studio" # Android IDE (JetBrains-based)
      "cursor" # AI code editor
      "docker" # Container runtime
      "temurin@11" # JDK 11 for WizyEMM backend (Kotlin 1.4.20)
      "intellij-idea" # Kotlin IDE (debugging, refactoring) — CE discontinued Dec 2026
      "karabiner-elements" # Keyboard customization (caps → hyper)
      "kitty" # Terminal
      "postgres-unofficial" # Local PostgreSQL (Postgres.app)
      "t3-code" # T3 Code desktop
      "visual-studio-code" # Editor (backup)

      # Tier 2: Productivity
      "1password" # Password manager
      "dropbox" # File sync
      "google-chrome" # Primary browser
      "firefox" # Secondary browser
      "slack" # Work communication
      "zoom" # Video calls

      # Tier 3: Communication
      "telegram" # Messaging
      "viber" # Messaging

      # Tier 3: Utilities (core casks unqualified, tap casks fully-qualified)
      # "grammarly-desktop"     # Writing assistance
      "blackhole-2ch" # Virtual audio driver for audio routing (meeting-record)
      "keycastr" # Keystroke visualizer - requires Input Monitoring permission
      "monitorcontrol" # External monitor brightness
      "obsidian" # Notes/knowledge base

      "repoprompt/repoprompt-ce/repoprompt-ce" # RepoPrompt Community Edition

      # AI-CLI observability cluster: codex/claude session viewer + usage monitor
      "jazzyalex/agent-sessions/agent-sessions" # Codex/Claude/Cursor/Gemini/Copilot session browser + analytics
      "steipete/tap/codexbar" # LLM usage monitoring (steipete/tap)
      "xykong/tap/flux-markdown" # Markdown previewer (xykong/tap)

      # Tier 4: Media/Other
      "discord" # Community/gaming
      "figma" # Design tool
      "nordvpn" # VPN client
      "spotify" # Music
      "steam" # Gaming
      "vlc" # Media player
    ];
  };

  # Homebrew PATH for all users
  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  # Homebrew 6.0's tap-trust enforcement reads trusted taps from
  # $HOMEBREW_USER_CONFIG_HOME/trust.json, which resolves to ~/.homebrew when
  # XDG_CONFIG_HOME is unset. nix-darwin invokes `brew bundle` via
  # `sudo --preserve-env=PATH`, stripping XDG_CONFIG_HOME, so activation's brew
  # looks in ~/.homebrew — while interactive `brew trust` writes to the XDG path
  # ~/.config/homebrew. Without this link the two stores diverge and activation
  # refuses every third-party tap even after it was trusted interactively.
  # extraActivation runs before the homebrew bundle step, so the link is present
  # in time (including on a fresh machine's first switch).
  system.activationScripts.extraActivation.text = ''
    brewTrustLink="${brewHome}/.homebrew"
    brewTrustTarget="${brewHome}/.config/homebrew"
    if [ ! -e "$brewTrustLink" ] || [ -L "$brewTrustLink" ]; then
      ln -sfn "$brewTrustTarget" "$brewTrustLink"
      chown -h ${brewUser}:staff "$brewTrustLink" 2>/dev/null || true
    fi
  '';
}
