# ADR-018: Full-access Codex abbreviations in Fish

**Status:** accepted
**Date:** 2026-01-04

## Context

Fish abbreviations in `nix/home/mp/modules/fish.nix` include `cdx` (`codex-launch`, default model) with `--sandbox=danger-full-access` and `--ask-for-approval=never`. These flags grant full access to the Codex CLI without additional approval prompts.

## Decision

Keep the abbreviations as-is and document them as a deliberate, user-approved exception.

Reasons:

1. The user explicitly requested these flags in the Fish configuration.
2. The workflow depends on fast iteration without repeated approvals.
3. Documenting the exception makes the risk explicit and reviewable.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Remove or restrict the abbreviations | Safer defaults | Slower workflow, breaks existing muscle memory |
| Keep as-is but document | Preserves workflow; explicit audit trail | Accepts elevated risk |

## Consequences

- Codex CLI can run with full access when invoked via these abbreviations.
- Increased risk if commands are run in untrusted repos or contexts.
- The exception must be re-evaluated if security posture changes.

## Migration

N/A — pre-existing abbreviations were retained and documented.

## Risks

Running `cdx` in an untrusted repo could allow Codex to take destructive actions without prompting. Mitigated by the user's awareness and the in-Nix comment that warns against modifying these flags.
