# ADR-005: GUI apps via Homebrew casks

**Status:** accepted
**Date:** 2025-12-25

> Revised by [ADR-016](016-homebrew-formulae-for-third-party-tap-tools.md) (2026-01-01) — `onActivation.cleanup` changed from `"zap"` to `"uninstall"` to protect stateful app data.

## Context

Need to install GUI applications (Chrome, Slack, VS Code, etc.).

Original decision (2025-12-24) deferred to manual installs for Phase 1; revised (2025-12-25) to Homebrew casks via nix-darwin.

## Decision

Use **Homebrew casks via nix-darwin** for GUI apps.

Reasons:

1. Declarative management of GUI apps in `hosts/m5-mbp/homebrew.nix`.
2. `onActivation.cleanup = "uninstall"` removes unlisted apps while preserving app data (per ADR-016).
3. nix-darwin runs `brew bundle` as `system.primaryUser`.
4. Reproducible across rebuilds.
5. Homebrew already needed for some apps not in nixpkgs.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Manual install | Simple, works | Not reproducible, manual tracking |
| Homebrew casks | Familiar, declarative via nix-darwin | Adds Homebrew footprint |
| Nix packages | Reproducible | Large closures, some apps unavailable |

## Consequences

- Homebrew installed manually once.
- Casks listed in `homebrew.nix`.
- `/opt/homebrew/bin` added to system PATH.
- App Store apps still manual.

## Migration

Initial migration moved a small set of casks into `homebrew.nix`; ongoing additions follow the existing list pattern.

## Risks

Homebrew taps are not in `flake.lock`; supply-chain assurance is weaker than for nixpkgs. Mitigations are tap-specific (see ADR-016).
