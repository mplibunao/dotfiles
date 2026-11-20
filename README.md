# Dotfiles

Personal macOS configuration managed with Nix (nix-darwin and Home Manager) for reproducible, declarative system setup.

## Quick Start (Fresh Mac)

1. **Check your current phase:**
   ```bash
   .claude/skills/bootstrap/scripts/bootstrap-check.sh
   ```

2. **Follow the bootstrap guide:**
   - See [`.claude/skills/bootstrap/SKILL.md`](.claude/skills/bootstrap/SKILL.md)
   - Or use Claude Code: run `/bootstrap`

3. **For existing Nix setups**, from the repository root:
   ```bash
   darwin-rebuild build --flake .#m5-mbp  # Build (safe)
   sudo darwin-rebuild switch --flake .#m5-mbp  # Apply
   ```

## What's Included

| Category | Tools |
|----------|-------|
| Shell | Fish + Starship prompt |
| Terminal | Kitty |
| Editor | Neovim (LazyVim) |
| Git | Delta, lazygit |
| Window Manager | AeroSpace |
| Package Manager | Nix + Homebrew (GUI apps) |

## Project Structure

```
dotfiles/
├── flake.nix               # Entry point
├── hosts/m5-mbp/           # Host-specific config
├── home/mp/                # Home Manager entry point and package tiers
├── modules/<tool>/         # One Home Manager module per tool, with the files it reads or links
├── packages/               # Custom package derivations
├── scripts/                # Operational scripts (nix-verify, nix-ops, ...)
├── tests/                  # Tests for the scripts and modules
├── data/                   # Data shared by modules (AeroSpace workspace registry)
├── docs/                   # Architecture docs, decisions, ledgers, investigations
│
├── .claude/                # Claude Code commands and the bootstrap skill
│
└── .github/workflows/      # Nix flake check on Linux
```

## Documentation

| Topic | Location |
|-------|----------|
| Agent Instructions | [`AGENTS.md`](AGENTS.md) |
| Architecture Docs | [`docs/architecture/index.md`](docs/architecture/index.md) |
| Checking and Applying a Change | [`docs/architecture/command-ladder.md`](docs/architecture/command-ladder.md) |
| Decisions | [`docs/decisions/README.md`](docs/decisions/README.md) |
| Bootstrap Guide | [`.claude/skills/bootstrap/SKILL.md`](.claude/skills/bootstrap/SKILL.md) |

## For Forkers

If you fork this repo, update these values before bootstrapping:

1. **GitHub username** in clone URLs
2. **Email** for SSH key generation
3. **Hostname** in flake commands (run `hostname -s` to get yours)

See the bootstrap guide for a personalization checklist.
