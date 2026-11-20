# Agent Instructions

## Nix Migration In Progress

**IMPORTANT**: This dotfiles repo is actively being migrated to Nix (nix-darwin + Home Manager).

- **Configurations outside `nix/` are mostly legacy** and may be deprecated
- **For Nix-specific guidance, see [`nix/AGENTS.md`](nix/AGENTS.md)** - contains safety rules, command ladder, and conventions
- **For fresh Mac setup, use the `/bootstrap` command** or see `.claude/skills/bootstrap/SKILL.md`
- When adding new configurations, prefer the Nix approach over legacy methods (Makefile, manual symlinks, etc.)

## Keyboard Layout

**IMPORTANT**: The user uses a **Dvorak keyboard layout**.

When suggesting or implementing keybindings:
- Consider Dvorak key positions (e.g., `h/j/k/l` are scattered, not a row)
- AeroSpace uses vim-style hjkl for navigation (character-based, for muscle memory)
- Prefer mnemonic bindings over positional ones when possible
- Document whether bindings are "Dvorak-native" or "QWERTY-positional"
