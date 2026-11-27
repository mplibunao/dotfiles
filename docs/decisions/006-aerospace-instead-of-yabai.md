# ADR-006: AeroSpace instead of Yabai

**Status:** accepted
**Date:** 2025-12-24

## Context

Need a tiling window manager for macOS.

## Decision

Use **AeroSpace** as primary window manager.

Reasons:

1. No SIP disable required (simpler setup).
2. Configuration via TOML (easy to manage).
3. Sufficient features for typical use.
4. Active development.
5. Works well with Nix file management.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Yabai | Powerful, familiar | Requires SIP disable, complex |
| AeroSpace | Simple, no SIP disable | Newer, less features |
| Rectangle | Simple | Not a full tiling WM |

## Consequences

- Migrate keybinds from skhd to AeroSpace config.
- Remove yabai/skhd from setup.
- Keep borders addon if visual separation desired.
- Config managed via Home Manager file mapping.

## Migration

Skhd / yabai uninstall + initial AeroSpace TOML conversion happened in Phase 1.

## Risks

AeroSpace is newer than yabai; missing features may surface later. Acceptable trade-off given the SIP-disable requirement of yabai.
