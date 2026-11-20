# ADR-024: Keep Phone Harness in a uv-managed environment

**Status:** accepted
**Date:** 2026-10-05

## Context

Phone Harness 0.3.0 passed bounded iPhone navigation tests using uv-managed Python 3.13.14 and PyObjC 12.2.2. Nix already supplies uv through Tier 2. The tested iPhone route operates through macOS iPhone Mirroring; a Linux VPS cannot provide that route. Phone Harness also documents Android operation over ADB on Linux, but that route has not been tested here.

The pinned nixpkgs provides several PyObjC 11.1 packages, but lacks Phone Harness and the Python bindings for Vision and CoreML. A native source-based package would need at least three local Nix definitions and verification against a different PyObjC version. These are Python bindings to frameworks already supplied by macOS, not builds of Apple's frameworks. No native Nix build was attempted, so this is a maintenance decision rather than a demonstrated Nix incompatibility.

## Decision

Keep the working Phone Harness installation managed by uv. Nix owns uv; uv owns the application's Python environment and executable. MP accepted this choice after reviewing the RP Build proposal and dependency explanation.

Keep Phone Harness configuration local and writable, including its existing telemetry opt-out and Android SDK adb path. No Nix recipe, activation step, executable bridge, custom helper, MCP entry, or new session-variable declaration is needed. Document installation, updates, and recovery in the [Phone Harness runbook](../runbooks/phone-harness.md).

## Alternatives considered

- **Native Nix packaging:** would bring the application into Nix builds and generation rollback. It needs local Phone Harness, PyObjC CoreML, and PyObjC Vision recipes. The existing package set uses untested bindings relative to our working install; matching 12.2.2 would require coordinated dependency changes. This remains a possible future approach, not selected now.
- **A Nix wrapper around uv:** adds another entry point without making the external environment part of Nix's reproducible package closure. Not needed.

## Consequences

- Preserve the tested installation with no new runtime code or packaging maintenance.
- Application updates and recovery are separate from Nix updates and rollback.
- Version constraints and the release cutoff are not a hash-locked dependency artifact set.
- The iPhone route's macOS requirement reduces the current benefit of reusing a package on a Linux VPS. This decision does not rule out future Android use on Linux.

## Migration

No installation migration. Retain the existing uv environment and telemetry configuration. Only documentation and the install-method catalog comment change.

## Risks

Unconstrained uv upgrades can change the working dependency combination. Follow the runbook and validate candidates before replacement. Revisit native Nix packaging if upstream packages become available, multiple hosts need this tool, or Nix-managed application rollback becomes worth the maintenance cost.
