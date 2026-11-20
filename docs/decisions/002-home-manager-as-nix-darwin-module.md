# ADR-002: Home Manager as a nix-darwin module (not standalone)

**Status:** accepted
**Date:** 2025-12-24

## Context

Home Manager can be used in three modes:

1. Standalone (`home-manager switch`)
2. NixOS module
3. nix-darwin module

## Decision

Use **Home Manager as a nix-darwin module**.

Reasons:

1. Single command (`darwin-rebuild switch`) updates everything.
2. Atomic system + user environment updates.
3. Shared nixpkgs evaluation (`useGlobalPkgs = true`).
4. Generations stay synchronized.
5. Cleaner profiles with `useUserPackages = true`.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Standalone | Independent of system, portable | Two commands to update, separate generations |
| nix-darwin module | Single command, atomic updates | macOS-specific, tighter coupling |

## Consequences

- No separate `home-manager` command needed.
- Configuration lives in nix-darwin modules.
- For Linux, would use a different mode (standalone or NixOS module).
- Rollback affects both system and home together.

## Migration

N/A — applied at first machine setup.

## Risks

A future Linux host would need its own Home Manager wiring. Acceptable given the current single-machine macOS scope.
