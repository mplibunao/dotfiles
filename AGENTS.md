# Agent Instructions

## Nix Migration In Progress

**IMPORTANT**: This dotfiles repo is actively being migrated to Nix (nix-darwin + Home Manager).

- **All configuration is in `nix/`**, except `karabiner/`, which Home Manager links into `~/.config/karabiner` from `~/Projects/personal/dotfiles/karabiner`
- **For Nix-specific guidance, see [`nix/AGENTS.md`](nix/AGENTS.md)** - contains safety rules, command ladder, and conventions
- **For fresh Mac setup, use the `/bootstrap` command** or see `.claude/skills/bootstrap/SKILL.md`
- When adding new configuration, add it as a Nix module rather than a manual symlink
- **Plans, ledgers, ADRs, and investigations:** where each goes and what gets committed is in [`docs/architecture/docs-and-records.md`](docs/architecture/docs-and-records.md)

## Keyboard Layout

**IMPORTANT**: The user uses a **Dvorak keyboard layout**.

When suggesting or implementing keybindings:
- Consider Dvorak key positions (e.g., `h/j/k/l` are scattered, not a row)
- AeroSpace uses vim-style hjkl for navigation (character-based, for muscle memory)
- Prefer mnemonic bindings over positional ones when possible
- Document whether bindings are "Dvorak-native" or "QWERTY-positional"
