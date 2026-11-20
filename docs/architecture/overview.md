# Architecture

> System design for the Nix-based macOS setup.

This document describes the layered architecture, component responsibilities, and boundaries of the declarative macOS configuration.

---

## System Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        macOS Host                               │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                   Determinate Nix                         │  │
│  │  • Nix daemon and CLI                                     │  │
│  │  • /nix/store                                             │  │
│  │  • Manages itself (upgrades, config)                      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                     nix-darwin                            │  │
│  │  • System-level macOS configuration                       │  │
│  │  • Fonts, security, networking                            │  │
│  │  • macOS defaults (Dock, Finder, etc.)                    │  │
│  │  • Homebrew integration (casks + limited brews via ADR-016)│  │
│  │                                                           │  │
│  │  Entry point: darwin-rebuild switch                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              ▼                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Home Manager (as nix-darwin module)          │  │
│  │  • User packages (~/.nix-profile or /etc/profiles/...)    │  │
│  │  • Dotfiles (~/.config/*, ~/.*rc)                         │  │
│  │  • User services (optional)                               │  │
│  │  • Shell configuration                                    │  │
│  │                                                           │  │
│  │  Driven by: darwin-rebuild (no separate home-manager cmd) │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer Responsibilities

### Determinate Nix (Installation Layer)

**Managed by:** Determinate Systems installer and `determinate-nixd`

**Responsibilities:**
- Nix daemon lifecycle
- `/nix/store` management
- Nix CLI and experimental features (flakes, nix-command)
- `/etc/nix/nix.conf` (Nix settings)

**Not managed by nix-darwin:**
Because Determinate Nix owns the Nix installation, we set:
```nix
nix.enable = false;
```
This disables nix-darwin's Nix management to prevent conflicts.

**Upgrade path:**
```bash
sudo determinate-nixd upgrade
```

---

### nix-darwin (System Layer)

**Managed by:** `darwin-rebuild switch`

**Responsibilities:**

| Area | Examples |
|------|----------|
| System packages | Fonts installed system-wide |
| macOS defaults | Dock autohide, key repeat rate, screenshots |
| Networking | DNS, firewall rules |
| Security | sudo TouchID, app sandboxing |
| Homebrew | Cask installation (and limited brews via ADR-016 exception) |
| Home Manager | Integration as a module |

**Configuration location:** `nix/hosts/<hostname>/configuration.nix`

**Key options:**
```nix
{
  nixpkgs.hostPlatform = "aarch64-darwin";  # Platform
  nix.enable = false;                        # Determinate owns Nix

  system.defaults.dock.autohide = true;
  system.defaults.NSGlobalDomain.KeyRepeat = 2;

  # Home Manager integration
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.mp = import ../../home/mp/darwin.nix;
}
```

---

### Home Manager (User Layer)

**Managed by:** `darwin-rebuild switch` (via nix-darwin module integration)

**Responsibilities:**

| Area | Examples |
|------|----------|
| User packages | CLI tools (git, nvim, fzf, ripgrep) |
| Dotfiles | `~/.config/fish/`, `~/.gitconfig`, `~/.config/kitty/` |
| Shell config | Fish functions, abbreviations, starship |
| Program config | Git settings, editor config |
| User services | Background daemons (rare on macOS) |

**Configuration locations:**
- `nix/home/mp/common.nix` - Cross-platform settings
- `nix/home/mp/darwin.nix` - macOS-specific settings
- `nix/home/mp/packages/tier*.nix` - Package lists by priority

**Key options:**
```nix
{
  home.username = "mp";
  home.homeDirectory = "/Users/mp";
  home.stateVersion = "24.11";  # Don't change after initial setup

  home.packages = with pkgs; [ ripgrep fd bat ];

  programs.git = {
    enable = true;
    userName = "MP";
    delta.enable = true;
  };

  xdg.configFile."kitty/kitty.conf".source = ./kitty.conf;
}
```

---

## Module Composition

### How Modules Import

```
flake.nix
    │
    ▼
darwinConfigurations."<hostname>"
    │
    ├── hosts/<hostname>/configuration.nix
    │       │
    │       ├── hosts/<hostname>/defaults.nix (host-specific macOS defaults)
    │       └── hosts/<hostname>/homebrew.nix (casks + brews)
    │
    └── home-manager.darwinModules.home-manager
            │
            └── home/mp/darwin.nix
                    │
                    ├── home/mp/common.nix (cross-platform)
                    ├── home/mp/packages/tier1.nix
                    ├── home/mp/packages/tier2.nix
                    └── home/mp/modules/*.nix (program modules)
```

### Shared vs Host-Specific

| Location | Purpose | When to Use |
|----------|---------|-------------|
| `home/mp/common.nix` | Cross-platform home | Settings that work on macOS and Linux |
| `home/mp/darwin.nix` | macOS home settings | macOS-specific paths, behaviors |
| `home/mp/modules/*.nix` | Program modules | Fish, Git, Kitty, Neovim, etc. |
| `hosts/<hostname>/*` | Per-host config | Machine-specific settings |

---

## Directory Layout

```
dotfiles/nix/
├── flake.nix                 # Flake entry point
├── flake.lock                # Pinned dependencies
├── README.md                 # Quick start
├── AGENTS.md                 # Agent guardrails (symlinked as CLAUDE.md)
│
├── hosts/
│   └── <hostname>/
│       ├── configuration.nix # nix-darwin host module
│       ├── defaults.nix      # macOS defaults for this host
│       └── homebrew.nix      # Homebrew casks and brews
│
├── home/
│   └── mp/
│       ├── common.nix        # Cross-platform home config
│       ├── darwin.nix        # macOS-specific home config
│       ├── packages/
│       │   ├── tier1.nix     # Essential (Day 1)
│       │   └── tier2.nix     # Development (Day 2-3)
│       └── modules/          # Program-specific configs
│           ├── fish.nix      # Shell config
│           ├── git.nix       # Git settings
│           ├── kitty.nix     # Terminal config
│           ├── neovim.nix    # Editor config
│           ├── node.nix      # Node.js/mise setup
│           └── ...
│
├── scripts/
│   ├── nix-locate            # Package search
│   ├── nix-ops               # Operational commands
│   └── nix-verify            # Verification ladder
│
└── docs/
    ├── 00-architecture.md    # This document
    ├── 01-migration-phases.md
    └── ...
```

---

## What Is NOT Captured

This Nix configuration does not manage:

### App Store Applications
- Require Apple ID
- No Nix packages available
- Document in a manual checklist

### Licensed Software Activation
- License keys
- Login credentials
- Serial numbers

### Cloud Service Authentication
- GitHub SSH keys (generate per-machine)
- gcloud auth login
- Docker Hub login

### Some macOS Settings
- Settings stored in opaque formats
- iCloud preferences
- App-specific databases

### Sensitive Data
- `.env` files
- Credentials
- API keys

### Per-Machine Hardware Config
- Display arrangements
- Bluetooth pairings
- Printer setup

---

## Key Design Decisions

### Why Determinate Nix?

1. **Simpler installer** with uninstall support
2. **Flakes enabled by default** (no manual config)
3. **Managed upgrades** via `determinate-nixd`
4. **Apple Silicon first** (official support dropped Intel)

Implication: `nix.enable = false` in nix-darwin.

### Why Home Manager as nix-darwin Module?

1. **Single entry point:** `darwin-rebuild` manages both system and user
2. **Shared nixpkgs:** `useGlobalPkgs = true` avoids duplicate evaluation
3. **Consistent profiles:** `useUserPackages = true` puts packages in `/etc/profiles/per-user/$USER`
4. **Atomic updates:** System and home update together

Alternative (standalone Home Manager) would require separate `home-manager switch` commands.

### Why Flakes?

1. **Pinned dependencies:** `flake.lock` ensures reproducibility
2. **Explicit inputs:** No reliance on NIX_PATH or channels
3. **Standard schema:** Clear structure for outputs
4. **Better caching:** Content-addressed store paths

Tradeoff: Flakes are still "experimental" but widely used and stable in practice.

### Why Tiered Packages?

1. **Minimize closure size:** Only install what's needed
2. **Staged migration:** Add packages deliberately
3. **Clear ownership:** Each package has a home
4. **Easy pruning:** Remove entire tiers if needed

See [02-packages-and-tiers.md](./02-packages-and-tiers.md) for tier definitions.

---

## Rebuild Workflow

```bash
# 1. Edit configuration
nvim nix/home/mp/packages/tier1.nix

# 2. Stage if new file
git add nix/...

# 3. Verify evaluation
nix flake check --no-build

# 4. Build (no apply)
darwin-rebuild build --flake .#<hostname>

# 5. Apply (when ready)
sudo darwin-rebuild switch --flake .#<hostname>
```

See [04-operations-update-rollback.md](./04-operations-update-rollback.md) for update and rollback procedures.
