# ADR-010: Canonical agent instructions at nix/AGENTS.md

**Status:** accepted
**Date:** 2025-12-26

## Context

Multiple files contained agent instructions for working with the Nix configuration:

- `docs/06-agent-guide.md` (detailed)
- Root `AGENTS.md` (beads-focused)
- Potential `CLAUDE.md` (Claude Code entrypoint)

This created confusion about which file was authoritative and risked drift between files.

## Decision

Create **`nix/AGENTS.md` as canonical** with full agent instructions. Both `CLAUDE.md` and `docs/06-agent-guide.md` symlink to it.

Reasons:

1. Single source of truth for agent behavior.
2. Both Claude Code and Codex find relevant instructions.
3. No drift between documentation files.
4. Symlinks preserve existing references.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Keep separate files | Each serves different purpose | Drift, duplication |
| Single AGENTS.md, symlink others | Single source of truth | May be too long |
| Short AGENTS.md, detailed in docs | Best of both | Still two places |

## Consequences

- `nix/AGENTS.md` is the authoritative file.
- `nix/CLAUDE.md → AGENTS.md` (symlink).
- `nix/docs/06-agent-guide.md → ../AGENTS.md` (symlink).
- Updates only needed in one place.

## Migration

Existing content consolidated into `nix/AGENTS.md`; `CLAUDE.md` and `06-agent-guide.md` were replaced by symlinks.

## Risks

If `AGENTS.md` grows too large, agents may run out of context attention. Periodic pruning required.
