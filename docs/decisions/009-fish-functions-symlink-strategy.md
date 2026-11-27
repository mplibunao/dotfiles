# ADR-009: Fish functions symlink strategy

**Status:** superseded
**Date:** 2025-12-26

> Superseded by [ADR-019](019-store-managed-file-mappings-by-default.md).

## Context

Fish functions need to be managed by Home Manager. Two approaches were available:

1. Store-managed: files copied to Nix store, symlinked from there.
2. Out-of-store: symlinks point directly to repo checkout (mutable).

## Decision

Original decision (2025-12-26): **store-managed approach** (`xdg.configFile` with normal sources).

Reasons originally cited:

1. Aligns with Home Manager's default declarative model.
2. Reproducible — functions are part of the Nix closure.
3. Atomic updates — functions update with system rebuild.
4. Consistent with `docs/03-dotfiles-mapping.md` priority order.
5. Could switch to out-of-store later if rebuild friction became an issue.

Superseded (2026-04-27): rebuild friction did become an issue. ADR-019 establishes per-condition criteria for choosing store-managed vs `mkOutOfStoreSymlink`. Authored Fish functions now meet condition 3 and use out-of-store mappings; generated Nix-owned completions such as `mise.fish` remain store-managed. `pnpm.fish` is generated outside Nix from the active Corepack-managed pnpm.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Store-managed (xdg.configFile) | Declarative, reproducible, atomic | Edit requires rebuild |
| Out-of-store (mkOutOfStoreSymlink) | Edit → immediate effect | Mutable, requires repo at path |

## Consequences

While in force, this ADR meant:

- Functions live at `nix/home/mp/modules/fish/functions/`.
- Editing a function required `darwin-rebuild switch` to take effect.
- Plugin functions remained isolated in the Nix store.

Under ADR-019, Fish authored function edits are live; see ADR-019 for the new behavior and the criteria.

## Migration

Replaced by ADR-019. See its Migration section for the `fish.nix` changes that supersede this decision.

## Risks

N/A — superseded.
