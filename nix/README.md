# Nix Configuration

Declarative macOS system and user configuration using **Determinate Nix + nix-darwin + Home Manager**.

> **Fresh Mac?** See the [bootstrap guide](../.claude/skills/bootstrap/SKILL.md) first.
> From repo root, run `.claude/skills/bootstrap/scripts/bootstrap-check.sh` to check your current phase.

## Prerequisites

- [Determinate Nix](https://determinate.systems/nix-installer) installed
- [Homebrew](https://brew.sh) installed (for GUI casks; some CLI brews via ADR-016 exception)
- macOS on Apple Silicon (`aarch64-darwin`)

## Quick Start

### Build (Safe)

```bash
# Evaluate syntax
nix flake check --no-build

# Build without applying
darwin-rebuild build --flake .#m5-mbp
```

### Apply (Requires Approval)

```bash
# Apply changes to the system
sudo darwin-rebuild switch --flake .#m5-mbp
```

### Update Inputs

```bash
# Update flake.lock
nix flake update

# Rebuild after update
darwin-rebuild build --flake .#m5-mbp
```

### Rollback (Requires Approval)

```bash
# List generations
darwin-rebuild --list-generations

# Rollback to previous (this is still a `switch`, requires explicit approval)
sudo darwin-rebuild switch --rollback
```

## Directory Structure

```
nix/
├── flake.nix                 # Entry point
├── flake.lock                # Pinned dependencies
├── AGENTS.md                 # Agent instructions (canonical)
├── CLAUDE.md                 # Symlink → AGENTS.md
│
├── hosts/m5-mbp/             # Host configuration
│   ├── configuration.nix     # nix-darwin config
│   └── homebrew.nix          # Homebrew casks and brews
│
├── home/mp/                  # User configuration
│   ├── common.nix            # Cross-platform settings
│   ├── darwin.nix            # macOS imports
│   ├── packages/
│   │   ├── tier1.nix         # Essential CLI tools
│   │   └── tier2.nix         # Development tools
│   └── modules/
│       ├── fish.nix          # Shell configuration
│       ├── git.nix           # Git + delta
│       ├── kitty.nix         # Terminal
│       ├── neovim.nix        # Editor
│       └── ...
│
├── scripts/                  # Operational scripts
│   ├── nix-locate            # Find nix root
│   ├── nix-verify            # Verification ladder
│   └── nix-ops               # Ops console
│
└── docs/                     # Documentation
    ├── 00-architecture.md    # System design
    ├── 01-migration-phases.md
    ├── 04-operations-update-rollback.md
    ├── codex-skill-symlinks.md
    └── ...
```

## Common Tasks

| Task | File to Edit |
|------|--------------|
| Add CLI package | `home/mp/packages/tier1.nix` or `tier2.nix` |
| Add GUI app | `hosts/m5-mbp/homebrew.nix` |
| Configure a program | `home/mp/modules/<program>.nix` |
| Add fish abbreviation | `home/mp/modules/fish.nix` → `shellAbbrs` |
| Add fish function | `home/mp/modules/fish/functions/` |
| Change macOS defaults | `hosts/m5-mbp/defaults.nix` (when created) |

## Operational Scripts

Once `nix/scripts/` is set up and on PATH:

```bash
# Verification ladder (safe)
nix-verify                    # Levels 0-2
nix-verify --to 3             # Include dry-run

# Operations console
nix-ops status                # Show diagnostics
nix-ops update-inputs --yes   # Update flake.lock
nix-ops generations           # List generations
nix-ops rollback              # Print rollback commands
nix-ops gc --apply            # Garbage collect
```

## Safety Rules

1. **Never run `switch` without explicit approval**
2. **Always stage new files before evaluation** (`git add`)
3. **Follow the ladder:** edit → stage → check → build → propose

See [AGENTS.md](AGENTS.md) for full agent guidelines.

## Manual Post-Install Steps

These settings cannot be automated via Nix and require one-time configuration:

### Developer Tools (faster compiles)

Add Kitty to Developer Tools to bypass Gatekeeper checks on compiled binaries:

1. System Settings → Privacy & Security → Developer Tools
2. Click `+` and add `/Applications/kitty.app`
3. Toggle it on

This speeds up Rust/C++ compile times significantly. See [blog post](https://nnethercote.github.io/2025/09/04/faster-rust-builds-on-mac.html).

### Screenshot Location (optional)

```bash
defaults write com.apple.screencapture location ~/Pictures/screenshots
killall SystemUIServer
```

## Documentation

| Topic | Document |
|-------|----------|
| Architecture | [docs/00-architecture.md](docs/00-architecture.md) |
| Migration phases | [docs/01-migration-phases.md](docs/01-migration-phases.md) |
| Package tiers | [docs/02-packages-and-tiers.md](docs/02-packages-and-tiers.md) |
| Dotfile mapping | [docs/03-dotfiles-mapping.md](docs/03-dotfiles-mapping.md) |
| Update/Rollback | [docs/04-operations-update-rollback.md](docs/04-operations-update-rollback.md) |
| Storage management | [docs/05-storage-management.md](docs/05-storage-management.md) |
| Agent guide | [docs/06-agent-guide.md](docs/06-agent-guide.md) → AGENTS.md |
| Troubleshooting | [docs/07-troubleshooting.md](docs/07-troubleshooting.md) |
| Decisions log | [docs/decisions/](docs/decisions/README.md) (per-file ADRs; legacy [09-decisions-log.md](docs/09-decisions-log.md) is now a stub) |
