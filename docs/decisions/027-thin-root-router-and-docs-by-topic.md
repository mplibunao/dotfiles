# ADR-027: Thin root router and docs by topic

**Status:** accepted
**Date:** 2026-11-20

## Context

[ADR-010](010-canonical-agent-instructions-at-nix-agents-md.md) made `nix/AGENTS.md` the one file of agent instructions, with `nix/CLAUDE.md` and `nix/docs/06-agent-guide.md` as symlinks to it and the root `AGENTS.md` pointing there. That file grew to about 460 lines covering the safety rules, the command ladder, conventions, the `clm` launch log, AeroSpace operations, and a pitfall list, much of which `nix/README.md` and the numbered docs in `nix/docs/` repeated. ADR-010 named this risk: a file that grows too large loses the agent's attention.

Two later changes removed the reasons for a `nix/` folder. The flake moved to the repository root, so `nix/` held only docs. The repository became public with a convention for current docs and records in [`docs/architecture/docs-and-records.md`](../architecture/docs-and-records.md). The symlinked agent guide also resolved its relative links from `nix/docs/`, where six of them didn't exist.

## Decision

- The root `AGENTS.md`, with `CLAUDE.md` as a symlink to it, is a router. It says what the repository is, states only the rules no other document owns (approval before any switch, switching a change from its branch before the merge, staging new files before evaluation, and the Dvorak layout), and lists the documents by topic.
- Docs that describe how the configuration works now live in `docs/architecture/`, one topic per file, listed in `docs/architecture/index.md`. Runbooks live in `docs/architecture/runbooks/`.
- Judgment rules for changes live in the root `CODING_STANDARDS.md`, and Nix terms in the root `GLOSSARY.md`.
- ADRs live in `docs/decisions/`, keeping their numbers.
- `nix/AGENTS.md`, `nix/CLAUDE.md`, `nix/README.md`, and the `06-agent-guide.md` symlink are removed. Each rule they held has exactly one home, and other documents link to it.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Keep one long agent file, moved to the root | One place to look | Every session loads all of it; the attention problem stays |
| Keep `nix/AGENTS.md` and its symlinks | No moves | `nix/` no longer holds the configuration, and the symlinked guide's links stay broken |
| Router plus docs by topic | Short file every session; each topic read only when a task needs it | A rule is found only if the router lists its document |

## Consequences

- An agent reads a short router at the start of every session and the topic doc before acting on that topic.
- Links replace symlinks, so every document resolves its links from its own location.
- The router's topic list has to stay complete. A new topic doc needs a line there or in `docs/architecture/index.md`.

## Migration

ADRs written before this one name paths from the old layout. They keep their wording, and this map gives the current location.

| Old path | Current path |
|----------|--------------|
| `nix/AGENTS.md`, `nix/docs/06-agent-guide.md`, `nix/README.md` | `AGENTS.md`, with the content in `docs/architecture/` and `CODING_STANDARDS.md` |
| `nix/docs/<NN>-<topic>.md`, other `nix/docs/*.md` | `docs/architecture/<topic>.md` |
| `nix/docs/decisions/` | `docs/decisions/` |
| `nix/docs/runbooks/` | `docs/architecture/runbooks/` |
| `nix/flake.nix`, `./nix#<output>` | `flake.nix`, `.#<output>` |
| `nix/hosts/`, `nix/packages/`, `nix/scripts/`, `nix/tests/`, `nix/data/` | `hosts/`, `packages/`, `scripts/`, `tests/`, `data/` |
| `nix/home/mp/modules/<tool>.nix` and the files beside it | `modules/<tool>/default.nix` and the files in that folder |
| `nix/home/mp/packages/tier*.nix` | `home/mp/package-tiers/tier*.nix` |

## Risks

The router can drift from the docs: a new rule written into a topic doc that the router doesn't route to, or a rule restated in two places. Signals to revisit: an agent misses a rule because nothing pointed it at the right document, or `AGENTS.md` grows past a screen of text.
