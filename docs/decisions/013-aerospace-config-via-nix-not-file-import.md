# ADR-013: AeroSpace config via Nix (not file import)

**Status:** superseded
**Date:** 2025-12-27

> Superseded by [ADR-014](014-aerospace-toml-as-canonical-authored-config.md).

## Context

AeroSpace configuration can be managed two ways:

1. **TOML import**: Keep `keybinds/sources/aerospace/aerospace.toml` as canonical, import via `builtins.fromTOML` in Nix.
2. **Nix-native**: Build settings purely in Nix, keep TOML for keybind inventory only.

## Decision

Original decision: use **Nix-native settings** in `aerospace.nix`. The TOML file at `keybinds/sources/aerospace/aerospace.toml` was maintained separately for keybind conflict detection but not imported.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| TOML as source, import in Nix | Single source of truth, keybinds system aligned | TOML must be valid for Nix, two representations |
| Nix-native settings | Type-checked, IDE support, single language | TOML drifts, manual sync for keybind inventory |

## Consequences

The dual-source approach created drift risk. Keybindings had to be maintained in two places (`aerospace.nix` and `aerospace.toml`), with no automated check for consistency. ADR-014 adopts TOML as canonical authored config, with Nix importing and overlaying only what it owns.

## Migration

Superseded by ADR-014; see its Migration section.

## Risks

N/A — superseded.
