# ADR-004: Node.js via fnm (Fast Node Manager)

**Status:** superseded by [ADR-020](020-nodejs-via-mise.md)
**Date:** 2025-12-25

## Context

Need to manage Node.js versions for projects and global CLIs (claude-code, codex, etc.).

Original decision (2025-12-24) chose Volta; revised (2025-12-25) to fnm because fnm reads `.nvmrc` and `.node-version` natively and is in nixpkgs.

## Decision

Use **fnm** for Node.js management.

Reasons:

1. Auto-detects `.nvmrc` and `.node-version` (compatible with work projects).
2. Fast Rust-based switching.
3. Available in nixpkgs (fully managed by Nix).
4. `--use-on-cd` flag auto-switches versions when entering directories.
5. Global CLIs (claude-code, codex) work naturally.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Volta | Fast switching, familiar | Own pinning syntax, doesn't read .nvmrc |
| fnm | Fast, reads .nvmrc/.node-version, Nix-installable | Less familiar |
| Nix native | Reproducible, unified tooling | Heavier closures, more complex |
| nvm | Familiar, reads .nvmrc | Shell-specific, slower |

## Consequences

- fnm installed via Nix (`home.packages`).
- Fish shell init sources fnm env with `--use-on-cd`.
- Node versions stored in `~/.local/share/fnm`.
- Global npm packages not tracked by Nix.
- Works seamlessly with existing `.nvmrc` files.

## Migration

N/A — applied at first machine setup.

## Risks

Global npm packages live outside the flake; reinstalling on a fresh machine requires manual or scripted recovery.
