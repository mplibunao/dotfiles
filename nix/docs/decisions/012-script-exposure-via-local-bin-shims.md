# ADR-012: Script exposure via HM-managed shims in ~/.local/bin

**Status:** accepted
**Date:** 2025-12-26

## Context

Operational scripts in `dotfiles/nix/scripts/` need to be accessible from any directory. Options:

1. Add `nix/scripts/` to PATH directly.
2. Package as Nix derivations.
3. Create symlinks/shims in `~/.local/bin`.

## Decision

Use **HM-managed symlinks in `~/.local/bin`** (already in PATH via `common.nix`). Symlinks are created with `mkOutOfStoreSymlink` so script edits take effect immediately.

Reasons:

1. Shell-agnostic (works in fish, bash, zsh).
2. Stable command names regardless of skill/dotfiles structure changes.
3. Uses existing PATH entry.
4. `mkOutOfStoreSymlink` allows immediate edit → effect for operational scripts (one of the precedent cases for ADR-019).

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| PATH to checkout | Out-of-store, immediate edits | Location-dependent, less reproducible |
| Nix derivations | Clean packaging | More Nix complexity for internal scripts |
| Shims in ~/.local/bin | Shell-agnostic, stable UX | Indirection |

## Consequences

- `nix-ops-tools.nix` module creates symlinks.
- Commands work from any directory.
- Edits to canonical scripts take effect immediately.
- Fish completions installed separately (currently store-managed; see ADR-019).

## Migration

`nix-ops-tools.nix` module added with the `mkOutOfStoreSymlink` shim pattern.

## Risks

Symlinks point at the working tree; renaming or moving the dotfiles checkout breaks them until next `darwin-rebuild switch`. Acceptable given the stable checkout path.
