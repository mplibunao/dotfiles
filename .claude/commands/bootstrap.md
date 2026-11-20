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
```

## Neovim

Phase 6 includes the Neovim config. Follow [Neovim (LazyVim config)](../skills/bootstrap/references/bootstrap-runbook.md#neovim-lazyvim-config) in the runbook, and see [Neovim validation fails](../skills/bootstrap/references/bootstrap-runbook.md#neovim-validation-fails) if it breaks. `.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --help` lists the script's options.

## References

- Full skill: `.claude/skills/bootstrap/SKILL.md`
- Detailed runbook: `.claude/skills/bootstrap/references/bootstrap-runbook.md`
- Agent rules and documents by topic: `AGENTS.md`
- Checks before a switch: `docs/architecture/command-ladder.md`
