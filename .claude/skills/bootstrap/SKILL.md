---
name: bootstrap
description: Bootstrap a fresh Mac with this dotfiles repo's Nix configuration. Use when setting up a new Mac, installing Determinate Nix, or getting to first darwin-rebuild. Covers pre-agent steps through handover to nix skill.
---

# Bootstrap

Guide for provisioning a fresh macOS machine until an agent can take over with the `nix` skill.

## Triggers

- "fresh Mac", "new Mac provisioning", "new Mac setup"
- "bootstrap Nix", "install Determinate Nix"
- "clone dotfiles", "setup dotfiles"
- "before nix-darwin works", "first time setup"

## Quick Status Check

```bash
# Check current bootstrap phase
.claude/skills/bootstrap/scripts/bootstrap-check.sh

# JSON output for scripting
.claude/skills/bootstrap/scripts/bootstrap-check.sh --json
```

## Phase Router

| Condition | Phase | Action |
|-----------|-------|--------|
| No Xcode CLT | 0 | Start from beginning |
| No SSH key | 1 | Generate SSH key |
| No dotfiles/claude-toolkit | 2 | Clone repos |
| No Homebrew | 3 | Install Homebrew |
| No Nix | 4 | Install Determinate Nix |
| Nix but no build | 5 | Bootstrap flake |
| Build works but missing tools/config | 6 | Install agent tools + Neovim config |
| Agent tools + Neovim config exist | 7 | **Handover** |

## Safety Rules

These rules align with `nix/AGENTS.md`:

1. **Never run `switch` without explicit user approval**
2. **Always stage new files** before flake evaluation
3. **Follow the ladder:** edit -> stage -> check -> build -> propose

## References

- [bootstrap-runbook.md](references/bootstrap-runbook.md) - Full 7-phase guide with detailed steps
- [bootstrap-neovim.sh](scripts/bootstrap-neovim.sh) - Clone + configure LazyVim config repo
- [nix/README.md](../../../nix/README.md) - Quick-start for Nix config
- [nix/AGENTS.md](../../../nix/AGENTS.md) - Agent safety rules and command ladder
- [nix/docs/01-migration-phases.md](../../../nix/docs/01-migration-phases.md) - Detailed migration phases

## Neovim Setup

### bootstrap-neovim.sh Options

```bash
# Basic setup: clone config + set fish NVIM_APPNAME
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh

# With plugin sync (runs headless Lazy! restore)
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --sync

# Validate existing setup (no clone, no fish var write)
.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --validate
```

### Lazy! Syntax

The script uses `Lazy!` (with bang) for synchronous plugin operations. The `!` makes lazy.nvim wait for completion before proceeding. Without it, Neovim may quit before plugins finish installing.

### Troubleshooting

| Problem | Solution |
|---------|----------|
| "lazy.nvim not found" | Check `init.lua` exists and has no syntax errors |
| "No plugins configured" | Run `--sync` or manually `:Lazy restore` |
| Native plugins not working | Run `--sync` (forces rebuild) |

See [bootstrap-runbook.md](references/bootstrap-runbook.md#neovim-validation-fails) for detailed troubleshooting.

## Handover

When Phase 7 is complete:

1. Run `bd ready` to check for available work
2. Use the `nix` skill for ongoing configuration changes
3. Point to `nix/AGENTS.md` for safety rules

```bash
# Verify handover
nix --version
darwin-rebuild --version
claude --version
NVIM_APPNAME=nvim-lazy nvim --version
```
