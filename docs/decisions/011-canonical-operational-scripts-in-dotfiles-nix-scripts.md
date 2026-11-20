# ADR-011: Canonical operational scripts in dotfiles/nix/scripts/

**Status:** accepted
**Date:** 2025-12-26

## Context

Operational scripts (`nix-ops`, `nix-verify`, `nix-locate`) existed only in claude-toolkit skill. The skill documentation claimed these were wrappers delegating to canonical scripts in `dotfiles/nix/scripts/`, but that directory didn't exist.

## Decision

Create **canonical scripts in `dotfiles/nix/scripts/`**. Skill scripts become thin wrappers that delegate to them.

Reasons:

1. Scripts version with the flake they operate on.
2. Changes to scripts are part of dotfiles history.
3. Skill wrappers remain stable while canonical implementations evolve.
4. Matches the architecture already documented in skill.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Keep in skill only | Simpler | Scripts not versioned with flake |
| Move to dotfiles | Versioned with config, single source | Skill needs wrappers |
| Duplicate | Both locations work | Drift risk |

## Consequences

- `nix/scripts/nix-locate`, `nix-verify`, `nix-ops` are canonical.
- Skill scripts are ~10-line wrappers.
- HM module installs shims in `~/.local/bin` (see ADR-012).

## Migration

Created `nix/scripts/` with canonical implementations; updated skill scripts to wrap them.

## Risks

Skill and canonical can drift if a wrapper is edited without re-checking the canonical. Mitigated by keeping wrappers extremely thin.
