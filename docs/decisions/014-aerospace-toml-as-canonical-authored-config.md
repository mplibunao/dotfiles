# ADR-014: AeroSpace TOML as canonical authored config

**Status:** accepted
**Date:** 2025-12-29

> Supersedes [ADR-013](013-aerospace-config-via-nix-not-file-import.md).

## Context

ADR-013 chose Nix-native settings for AeroSpace config. This created two files:

- `aerospace.nix` (Nix attrset, generated TOML)
- `aerospace.toml` (mirror for keybind tooling)

Manual sync was error-prone and caused drift between sources.

## Decision

Make **TOML the canonical authored config**. Nix imports and overlays minimal dynamic content.

### Ownership boundary (enforced)

| Owner | Content |
|-------|---------|
| TOML | keybindings, key-mapping, gaps, layout, normalization, after-startup-command |
| Nix  | `on-window-detected` (floatApps), `exec.env-vars.PATH`, packages |
| HM   | `start-at-login`, `after-login-command` (overridden by `launchd.enable`) |

Nix module includes assertions that fail the build if TOML contains Nix-owned keys:

```nix
assert !(baseConfig ? "on-window-detected");  # Nix owns float rules
assert !(baseConfig ? "exec");                # Nix owns PATH/env
assert !(baseConfig ? "start-at-login");      # HM overrides
assert !(baseConfig ? "after-login-command"); # HM overrides
```

### File structure

```
nix/home/mp/modules/aerospace/
├── default.nix      # Module imports TOML, overlays Nix-owned settings
└── aerospace.toml   # Canonical keybindings, gaps, layout
```

TOML must be inside the flake root for pure evaluation.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Keep dual-source | Both languages get native syntax | Drift risk, manual sync |
| TOML canonical + Nix overlay | Single source for keybindings | TOML can't express all Nix logic |
| Nix generates TOML for tooling | Nix is authoritative | Complex generation, tooling must parse generated file |

## Consequences

- Edit TOML for keybinding changes.
- Edit Nix only for float rules, PATH, packages.
- Keybind tooling reads same file Nix imports.
- No manual sync required.
- Assertions prevent accidental drift.

## Migration

Moved canonical content from `aerospace.nix` into `aerospace.toml`; switched module to import + overlay; added assertions.

## Risks

If TOML acquires a Nix-owned key (e.g. via copy-paste from upstream docs), the build fails. Intentional: prefer fail-fast over silent override. `darwin-rebuild build` plus a semantic comparison (Nix-evaluated settings minus Nix-owned keys equals canonical TOML) verifies the boundary.
