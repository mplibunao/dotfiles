# ADR-025: Override a stale OpenCode node_modules hash locally

**Status:** accepted
**Date:** 2026-11-02

## Context

[ADR-021](021-opencode-upstream-flake-for-repoprompt-acp.md) installs OpenCode from its upstream flake at a pinned release tag. RepoPrompt and T3 Code both use that one `opencode` executable, and T3 Code's OpenCode integration recommends OpenCode 2.0.18 or later.

The flake builds OpenCode's JavaScript dependencies as a separate fixed-output derivation named `opencode-node_modules`. A fixed-output derivation is a build step whose output must match a hash recorded in advance. Upstream records one hash per platform in `nix/hashes.json`.

Upstream's `bot-nix-hashes` workflow updates `nix/hashes.json` through a separate pull request after dependency changes reach its `dev` branch. Upstream can tag a release before that pull request merges, so a tag's `nix/hashes.json` can hold the hash of an earlier dependency tree. The v2.2.3 and v2.2.5 tags both include `bun.lock` changes made after their last hash update. At both tags, the `aarch64-darwin` hash does not match the download, and the build fails before it produces OpenCode.

## Decision

1. ADR-021 points 1 and 2 still apply: pin an upstream release tag and install that flake's `opencode` package.
2. When the pinned tag's own `node_modules` hash fails on a platform, set that platform's hash in `nix/packages/opencode/default.nix` to the hash Nix reports in the mismatch error. The override changes only the expected hash. The source tree, `bun.lock`, and build steps still come from the tag.
3. `tier1.nix` and `llm-tools.nix` both take the package from `nix/packages/opencode/default.nix`, so the Tier 1 package and the `~/.local/bin/opencode` bridge remain one store path.
4. Every tag change follows the [upgrade procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-upgrade), which first builds without the override and adds a hash only for a platform where the tag's own hash fails.

This decision revises ADR-021 point 2 only.

## Alternatives considered

| Option | Why rejected |
|---|---|
| Stay on OpenCode 1 | T3 Code shows OpenCode 1 as limited support. |
| Pin a `dev` commit whose hashes the upstream bot updated | Installs unreleased code. |
| Upstream installer or Homebrew | ADR-021 rejects both: a weaker lock and rollback boundary, and a competing executable. |
| Fork the flake to correct `nix/hashes.json` | Adds a fork to maintain for a one-line difference. |

## Consequences

- OpenCode 2 builds from an upstream release tag on this host.
- Each tag change needs one extra build to find out whether an override is still required.
- A stale override stops the build with a hash mismatch. It cannot install a different dependency tree.

## Migration

`nix/packages/opencode/default.nix` holds the `aarch64-darwin` hash for v2.2.5. `tier1.nix` and `llm-tools.nix` call it with `pkgs.callPackage` instead of reading the flake package directly.

## Risks

- The override records the hash of this machine's first download rather than one upstream published. A later download with different content fails with a hash mismatch rather than installing.
- If `bun install` does not produce identical output on every run, a rebuild after garbage collection can fail with a new hash. Repeat the upgrade procedure's hash step if that happens.
- Upstream may stop publishing Darwin hashes or change the flake's package arguments. Either change breaks the override at evaluation or build time.
