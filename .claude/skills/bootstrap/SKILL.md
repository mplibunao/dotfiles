---
name: bootstrap
description: Bootstrap a fresh Mac with this dotfiles repo's Nix configuration. Use when setting up a new Mac, installing Determinate Nix, or getting to first darwin-rebuild. Covers pre-agent steps through handover to the repository's AGENTS.md.
---

# Bootstrap

Guide for provisioning a fresh macOS machine until an agent can take over by following the repository's `AGENTS.md`.

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

Follow the [rules in `AGENTS.md`](../../../AGENTS.md#rules), starting with the user's approval before any `switch`.

## References

- [bootstrap-runbook.md](references/bootstrap-runbook.md) - Full 7-phase guide with detailed steps
- [bootstrap-neovim.sh](scripts/bootstrap-neovim.sh) - Clone + configure LazyVim config repo
- [AGENTS.md](../../../AGENTS.md) - Agent rules and documents by topic
- [command-ladder.md](../../../docs/architecture/command-ladder.md) - Checks from evaluation to an approved switch
- [hosts.md](../../../docs/architecture/hosts.md) - Adding a host for a new hostname

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

1. Follow the repository's `AGENTS.md` for ongoing configuration changes; it states the safety rules and links the document for each topic

```bash
# Verify handover
nix --version
darwin-rebuild --version
claude --version
NVIM_APPNAME=nvim-lazy nvim --version
```
