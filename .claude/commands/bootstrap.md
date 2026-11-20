---
allowed-tools: Bash, Read
description: Bootstrap a fresh Mac with Nix configuration (7-phase guide)
---

# bootstrap

Wrapper for the bootstrap skill. Use when setting up a fresh macOS machine with this dotfiles repo.

## Instructions

1. Read the skill instructions: `.claude/skills/bootstrap/SKILL.md`
2. Run the status check to determine current phase:
   ```bash
   .claude/skills/bootstrap/scripts/bootstrap-check.sh
   ```
3. Follow the phase-appropriate steps from the skill

## Quick Reference

```bash
# Check current phase (human-readable)
.claude/skills/bootstrap/scripts/bootstrap-check.sh

# Check current phase (JSON for scripting)
.claude/skills/bootstrap/scripts/bootstrap-check.sh --json

# Get just the phase number
.claude/skills/bootstrap/scripts/bootstrap-check.sh --phase

# Setup Neovim config (clone + fish NVIM_APPNAME)
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh

# Setup with headless plugin sync (uses Lazy! for synchronous restore)
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --sync

# Validate existing Neovim setup (no clone, no writes)
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --validate
```

## Neovim Troubleshooting

| Problem | Solution |
|---------|----------|
| "lazy.nvim not found" | Check `init.lua` exists, no syntax errors |
| "No plugins configured" | Run with `--sync` or `:Lazy restore` in nvim |
| Validation fails | Open nvim interactively for full errors |

**Note:** `nvim --headless` may write to `~/.local/share/nvim` and `~/.local/state/nvim`.

## References

- Full skill: `.claude/skills/bootstrap/SKILL.md`
- Detailed runbook: `.claude/skills/bootstrap/references/bootstrap-runbook.md`
- Agent rules and documents by topic: `AGENTS.md`
- Checks before a switch: `docs/architecture/command-ladder.md`
