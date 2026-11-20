# ADR-015: Manually managed GUI apps system

**Status:** accepted
**Date:** 2025-12-29

## Context

Some GUI apps cannot be managed via Homebrew casks (no cask exists or unsuitable) but still need reproducible tracking and safe update workflows. Example: AudioPriorityBar for keeping external mic as default input (fixes Whispering choosing iPhone mic). AudioPriorityBar's current release artifacts are unsigned, so the manifest must explicitly allow that exception.

ADR-005 established Homebrew casks as the default for GUI apps, but some apps have no cask and cannot use that path.

## Decision

Use a single **`manual-apps/`** subsystem at repo root with:

- `manifest.json` — declarative app inventory.
- `manual-apps.py` — Python CLI for check/update operations.
- GitHub releases as the default update strategy.

Reasons:

1. **Scalable**: N apps with 1 tool (no per-app commands).
2. **Reproducible**: Manifest declares expected state.
3. **Safe**: Mandatory authenticity verification (codesign + spctl).
4. **Standalone**: Works from Terminal without Claude permissions.
5. **Two-phase UX**: check shows changes → confirm → update.

### Security features

- HTTPS-only downloads.
- Path traversal protection in zip extraction.
- Symlink detection (reject `.app` symlinks).
- codesign signature verification (default; exceptions require `allow_unsigned`).
- spctl Gatekeeper assessment (default; exceptions require `allow_unnotarized` or `allow_adhoc`).
- Bundle ID and Team ID pinning via manifest.
- Atomic install with automatic rollback on failure.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Ad-hoc manual installs | Simple | Not reproducible, easy to forget |
| Per-app skills/commands | Documented | Doesn't scale, command explosion |
| Single manifest + updater CLI | Scalable, reproducible | New subsystem to maintain |

## Consequences

- New `manual-apps/` directory at repo root (outside `nix/`).
- Clear boundary from Homebrew casks (different tools for different needs).
- Documented in `nix/docs/gui-apps.md`.
- Claude command operates in runbook mode (prints commands to run).
- Never writes state to the repo (writes local state to `~/Library/Application Support/manual-apps/state.json`).

## Migration

`manual-apps/` created; AudioPriorityBar onboarded as the first managed entry with `allow_unsigned` due to upstream artifact policy.

## Risks

Allow-list exceptions (`allow_unsigned`, `allow_unnotarized`) bypass macOS authenticity guarantees. Mitigated by per-app justification recorded in the manifest.
