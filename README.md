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
├── nix/                    # Nix documentation and agent instructions
│
├── .claude/                # Claude Code commands and the bootstrap skill
│
└── .github/workflows/      # Nix flake check on Linux
```

## Documentation

| Topic | Location |
|-------|----------|
| Nix Quick Start | [`nix/README.md`](nix/README.md) |
| Agent Instructions | [`nix/AGENTS.md`](nix/AGENTS.md) |
| Architecture | [`nix/docs/00-architecture.md`](nix/docs/00-architecture.md) |
| Migration Phases | [`nix/docs/01-migration-phases.md`](nix/docs/01-migration-phases.md) |
| Bootstrap Guide | [`.claude/skills/bootstrap/SKILL.md`](.claude/skills/bootstrap/SKILL.md) |

## For Forkers

If you fork this repo, update these values before bootstrapping:

1. **GitHub username** in clone URLs
2. **Email** for SSH key generation
3. **Hostname** in flake commands (run `hostname -s` to get yours)

See the bootstrap guide for a personalization checklist.
