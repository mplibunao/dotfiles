# Decisions Log

> **This file is no longer the source of truth.** Per-file ADRs live in [`decisions/`](decisions/README.md). See that index for all entries.

This stub remains so older internal links and external references continue to resolve to the right place.

## Where ADRs live now

- **Index:** [`decisions/README.md`](decisions/README.md)
- **Template:** [`decisions/template.md`](decisions/template.md)
- **Format:** one Markdown file per ADR, `NNN-kebab-case-slug.md`, mirroring `claude-toolkit/docs/decisions/`.

## Migration history

ADRs 001–018 originally lived in this monolithic file. On 2026-04-27 they were split into per-file format alongside the new ADR-019 (which formalized the per-file convention going forward).

The split is **structure-preserving with light template normalization**:

- Each ADR was reshaped to the toolkit template (`decisions/template.md`): `Context` → `Decision` → `Alternatives considered` → `Consequences` → `Migration` → `Risks`. The monolithic format used a `Rationale` section and ad-hoc tail sections ("Implementation Details", "Examples", "Verification", "Rollback", "See Also"); their substance was folded into the matching toolkit sections, and `Migration` / `Risks` were added per ADR (synthesized from original content where applicable, marked `N/A` for behavioral-only decisions).
- Status values lowercased (`Accepted` → `accepted`, etc.) to match toolkit convention.

Material content normalizations (beyond format):

1. **ADR-009** status changed from `Accepted` to `superseded by ADR-019` — the new ADR explicitly supersedes 009's "store-managed default for fish functions" decision.
2. **ADR-016** "Examples" list updated to include `rtk` (added to `homebrew.nix` in the same session).

ADR-019 itself is new and never lived in this monolithic file.

