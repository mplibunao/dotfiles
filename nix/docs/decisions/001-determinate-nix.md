# ADR-001: Use Determinate Nix instead of upstream

**Status:** accepted
**Date:** 2025-12-24

## Context

Need to install Nix on a new Apple Silicon Mac. Two main options:

1. Upstream Nix via official installer
2. Determinate Nix via Determinate Systems installer

## Decision

Use **Determinate Nix**.

Reasons:

1. Simpler installation with reliable uninstaller.
2. Flakes enabled by default (no extra configuration).
3. Managed upgrades via `determinate-nixd`.
4. Apple Silicon first-class support.
5. Aligns with the flake-first approach.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Upstream Nix | Official, well-documented | Complex uninstall, flakes not default |
| Determinate Nix | Easy install/uninstall, flakes enabled, managed upgrades | Separate from upstream, Intel dropped |

## Consequences

- Must set `nix.enable = false` in nix-darwin (Determinate owns Nix).
- Some nix-darwin `nix.*` options will not work.
- Cannot use on Intel Macs (would need upstream Nix if needed later).
- Upgrade via `sudo determinate-nixd upgrade` instead of `nix-channel`.

## Migration

N/A — applied at first machine setup.

## Risks

If Determinate Systems abandons the project or diverges meaningfully from upstream, migrating away requires re-installing Nix and re-evaluating the flake. Low probability today.
