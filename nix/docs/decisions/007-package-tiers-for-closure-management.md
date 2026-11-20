# ADR-007: Package tiers for closure management

**Status:** accepted
**Date:** 2025-12-24

## Context

Need to control closure size and disk usage (1TB constraint).

## Decision

Use **tiered package lists** (Tier 1–3 + Evaluate).

Reasons:

1. Explicit control over what's installed.
2. Easy to disable a tier to reduce closure.
3. Clear ownership: each package has a home.
4. Maps directly to migration phases.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Single package list | Simple | Large closures, hard to trim |
| Tiered packages | Controlled growth, easy to disable | More files, more decisions |
| Per-project only | Minimal global | Inconvenient for global tools |

## Consequences

- New packages require a tier decision.
- Tier files in `home/mp/packages/`.
- Must import tiers in home config.
- Regular review to prune the Evaluate tier.

## Migration

Initial tier files created in Phase 1; new packages slot into the appropriate tier per `docs/02-packages-and-tiers.md`.

## Risks

Tier creep: anything ambiguous tends to drift into Tier 1. Mitigated by periodic Evaluate-tier review.
