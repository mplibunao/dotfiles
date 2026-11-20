# ADR-008: Move to nixpkgs-unstable + nix-darwin master

**Status:** accepted
**Date:** 2025-12-25

> Supersedes [ADR-003](003-nixpkgs-branch-for-darwin.md).

## Context

Needed Homebrew cask integration with nix-darwin. The `system.primaryUser` option (required for running `brew bundle` as user instead of root) is only available in nix-darwin master, which requires nixpkgs-unstable.

## Decision

Upgrade to **nixpkgs-unstable + nix-darwin master + home-manager master**.

Reasons:

1. Enables `system.primaryUser = "mp"` for Homebrew.
2. Declarative GUI app management via casks.
3. Access to latest features.
4. Acceptable trade-off for reproducible GUI apps.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Stay on stable, manual brew | Stable, predictable | GUI apps not declarative |
| Upgrade to unstable | Homebrew integration works | More updates, option renames |

## Consequences

- Flake inputs changed to unstable/master branches.
- Home Manager options renamed (e.g. git.nix updated).
- More frequent updates when running `nix flake update`.
- Larger downloads on updates.

## Migration

Replaced `flake.nix` inputs to point at unstable/master; updated affected modules (e.g. `git.nix`) for renamed options.

## Risks

Master branches occasionally introduce option renames or breakage. Mitigated by checking `darwin-rebuild build` before applying and by holding back via `flake.lock` when an update misbehaves.
