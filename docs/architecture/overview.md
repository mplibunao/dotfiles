# Overview

The layers of the declarative macOS configuration, what each one owns, and what stays outside Nix. [Repository layout](repository-layout.md) shows where the files are.

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
Because Determinate Nix owns the Nix installation, the host sets `nix.enable = false` ([`configuration.nix`](../../hosts/m5-mbp/configuration.nix)). This disables nix-darwin's Nix management to prevent conflicts.

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

**Configuration location:** `hosts/<hostname>/configuration.nix`; see [Hosts](hosts.md)

**Key settings:** [`configuration.nix`](../../hosts/m5-mbp/configuration.nix) wires in Home Manager. It also sets the platform and turns off nix-darwin's Nix management. [`defaults.nix`](../../hosts/m5-mbp/defaults.nix) holds the macOS defaults, and [`homebrew.nix`](../../hosts/m5-mbp/homebrew.nix) the Homebrew casks and brews.

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

**Configuration locations:** `home/mp/` and `modules/<tool>/`. [Wiring](#wiring) shows how they connect.

**Key settings:** [`common.nix`](../../home/mp/common.nix) sets the user, home directory, state version, and session variables. Set the state version once and never change it ([Operations](operations.md#state-version-rules)).

---

## Wiring

Following the imports from the flake shows where each setting comes from:

1. [`flake.nix`](../../flake.nix) defines `darwinConfigurations."m5-mbp"`, which combines the host module with the Home Manager nix-darwin module.
2. [`hosts/m5-mbp/configuration.nix`](../../hosts/m5-mbp/configuration.nix) imports [`homebrew.nix`](../../hosts/m5-mbp/homebrew.nix) and [`defaults.nix`](../../hosts/m5-mbp/defaults.nix), and sets `home-manager.users.mp` to [`home/mp/darwin.nix`](../../home/mp/darwin.nix).
3. `home/mp/darwin.nix` imports [`common.nix`](../../home/mp/common.nix), the two [package tier](packages-and-tiers.md) files, and one module per tool from `modules/`.

[Repository layout](repository-layout.md) says where a new change goes, and [Cross-platform](cross-platform.md#platform-boundaries) says where shared code ends and macOS-only code begins.

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

See [Packages and tiers](packages-and-tiers.md) for tier definitions.

---

## Rebuilding

The [command ladder](command-ladder.md) gives the order for checking and applying a change, and [Operations](operations.md) covers updates and rollback.
