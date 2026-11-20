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

3. **For a Mac that already builds**, check a change with the [command ladder](docs/architecture/command-ladder.md). Its last step, the switch, needs approval ([`AGENTS.md`](AGENTS.md)).

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

[Repository layout](docs/architecture/repository-layout.md) shows what each folder contains and where a change goes.

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
