# ADR-016: Homebrew formula exceptions for CLI tools and runtime dependencies

**Status:** accepted
**Date:** 2026-01-01

> Revises [ADR-005](005-gui-apps-via-homebrew-casks.md) — `onActivation.cleanup` changed from `"zap"` to `"uninstall"`.

## Context

Some CLI tools and macOS runtime dependencies are not available in nixpkgs, are not practical to package locally yet, require Homebrew-provided bottles or dylibs, or are distributed first through third-party Homebrew taps. Current examples include core formulae like `sqlite` and tools from taps such as `gildas/tap`. These include macOS-specific tools, agent workflow tools, runtime dylib dependencies, and tools where the upstream macOS path is Homebrew. Additionally, when adding stateful GUI apps, the destructive `cleanup = "zap"` policy poses unacceptable data loss risk.

## Decision

1. Homebrew formulae may be used for CLI tools when:
   - The tool is not available in nixpkgs, or local Nix packaging would add more maintenance than the tool currently justifies.
   - Upstream recommends Homebrew as the primary macOS install method.
   - The tool requires macOS-specific entitlements, runtime dependencies, or tap-provided bottles that are materially simpler than a local package.
2. Change `onActivation.cleanup` from `"zap"` to `"uninstall"` to protect stateful app data.

Reasons:

1. Tools like RTK and Mole are not available in the pinned nixpkgs and ship as Homebrew formulae.
2. Stateful apps (Dropbox, Telegram, Viber, Grammarly) would lose data on accidental zap.
3. `uninstall` cleanup is safer: removes apps but preserves data directories.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Skip third-party tools | No tap dependency | Miss useful tools |
| Package for nixpkgs or local overlays | Reproducible | Time-consuming, maintenance burden |
| Use upstream direct installers/npm globals | Follows some upstream paths | Not managed by nix-darwin cleanup or system review |
| Homebrew exception | Quick, follows upstream, declarative through nix-darwin | Not in flake.lock, third-party tap supply-chain risk |

## Consequences

- Third-party taps become dependencies (such as `steipete/tap`) when tapped formulae or casks are declared.
- These formulae are not reproducible via `flake.lock`.
- Third-party formula taps require audit/smoke verification after install or tap updates.
- Removed apps leave behind data in `~/Library/Application Support/` (acceptable trade-off).

### Examples currently in use

- `watchman` — File watching for Jest in the work web projects.
- `rtk` — LLM token-compression CLI proxy.
- `sqlite` — Runtime `libsqlite3.dylib` dependency for gno's macOS sqlite-vec integration.
- `swiftlint` — Swift linter for RepoPrompt CE, whose format tooling installs it through Homebrew.
- `steipete/tap/codexbar` — LLM usage monitoring cask.

## Migration

`hosts/m5-mbp/homebrew.nix` extended with the brews/casks above; `onActivation.cleanup` flipped to `"uninstall"`.

## Risks

Homebrew formula maintainers may change formula behavior or publish a compromised update, and third-party tap maintainers may abandon a tap; mitigated by keeping the formula and tap lists small, reviewing formula metadata and tap commits after install or updates, and re-evaluating any tap that becomes unmaintained.
