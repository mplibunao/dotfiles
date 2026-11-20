# ADR-003: Nixpkgs branch for Darwin

**Status:** superseded
**Date:** 2025-12-25

> Superseded by [ADR-008](008-nixpkgs-unstable-nix-darwin-master.md).

## Context

Need to choose between stable and unstable nixpkgs for macOS.

## Decision

Original (2025-12-24): Use **stable Darwin branch** (`nixpkgs-24.11-darwin`).

Revised (2025-12-25): Moved to **nixpkgs-unstable + nix-darwin master** to get `system.primaryUser`, required for Homebrew cask integration. See [ADR-008](008-nixpkgs-unstable-nix-darwin-master.md).

## Alternatives considered

Captured in ADR-008.

## Consequences

- More frequent updates after the move to unstable.
- Access to latest features (`system.primaryUser`).
- Home Manager options may change between updates (see git.nix migration).

## Migration

Superseded by ADR-008. No active migration tasks remain on this ADR.

## Risks

N/A — superseded.
