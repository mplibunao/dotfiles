# ADR-021: Use the upstream OpenCode flake for RepoPrompt ACP

**Status:** accepted
**Date:** 2026-08-25

## Context

RepoPrompt CE has a compiled OpenCode ACP provider, but it needs a compatible `opencode` executable that a GUI-launched process can discover. The initial rollout targets OpenCode `v1.18.21` on `m5-mbp` and must preserve reproducibility without putting mutable authentication, provider, model, or MCP state in the Nix store.

The available installation sources have different tradeoffs. The nixpkgs package observed during planning lagged the selected release, while the upstream Homebrew tap and direct installers weaken the flake lock and generation rollback boundary. OpenCode's upstream flake publishes a Darwin package with its own tested dependency graph.

RepoPrompt's GUI-native paths include `~/.local/bin`, while its OpenCode-specific `~/.opencode/bin` hint may take precedence when shell environment discovery is degraded. The rollout therefore also needs one explicit discovery bridge and collision checks that prevent an older executable from silently winning.

## Decision

1. Pin `github:anomalyco/opencode/v1.18.21` as an independent flake input. Do not make its nixpkgs input follow the dotfiles nixpkgs; retain the upstream-tested lock graph.
2. **Revised by [ADR-025](025-opencode-node-modules-hash-override.md), which allows a local `node_modules` hash override for a platform whose tag hash is stale.** Install `opencode.packages.${pkgs.stdenv.hostPlatform.system}.opencode` as a Tier 1 package because RepoPrompt Agent Mode/MCP is a primary agent workflow.
3. Expose the same immutable package binary through a normal store-managed `home.file` link at `~/.local/bin/opencode`, owned by `llm-tools.nix`. This is a GUI discovery bridge, not a wrapper or second installation.
4. **Superseded by [ADR-023](023-opencode-cursor-client-config-ownership.md) for the exact `opencode.jsonc` file.** OpenCode credentials, sessions, history, its configuration directory, and project configuration remain outside Nix. The managed file retains non-secret model defaults and provider settings; per-session provider/model selection remains operator-owned under point 6.
5. Use RepoPrompt's process-ephemeral MCP and permission overlay for normal launches. Do not create a persistent `mcp.RepoPromptCE` entry by default.
6. Authentication remains operator-owned through OpenCode's upstream interface; multiple provider credentials may coexist, while provider/model and explore/engineer/pair/design role choices remain in OpenCode and RepoPrompt rather than Nix. Follow the canonical [credential commands and lifecycle](../architecture/runbooks/opencode-repoprompt.md#opencode-credential-lifecycle).
7. Add no custom auth wrapper, external OpenCode plugins, daemon, launchd service, or standalone service configuration. The runbook is an intentional exception to `nix/AGENTS.md` Rule 4 for interactive provider selection, browser OAuth, and secret entry: these operator-driven actions cannot be safely scripted, and the upstream CLI is the operational mechanism.
8. An intentional release upgrade requires an explicit tag edit and targeted update of the `opencode` input. Because Git tags can move, review the locked revision and `narHash` on every update even when the tag text is unchanged. Follow the canonical [upgrade procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-upgrade).
9. Activation requires one intended OpenCode executable and no higher-priority competitor; never bypass a collision with `force = true`. Follow the canonical [prerequisite and collision procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-prerequisites-collisions).
10. Activation remains subject to the repository's explicit user-approval gate.

## Alternatives considered

| Option | Advantages | Why rejected for the initial rollout |
|---|---|---|
| `pkgs.opencode` | Small lock graph; conventional nixpkgs ownership | Observed package lag did not provide the selected ACP-known release |
| Upstream OpenCode flake (chosen) | Exact tagged release; reproducible package and rollback boundary; Darwin output | Adds an independent lock graph and may require an uncached build |
| Homebrew upstream tap | Current macOS bottles; upstream-supported | Not pinned by `flake.lock`; weaker generation rollback and executable identity |
| Direct installer, npm, or Bun global | Simple upstream onboarding | Mutable global installation can drift and compete with the managed bridge |
| Wrapper script | Could combine checks and auth prompts | Hides the upstream provider picker and adds maintenance without a safety benefit |
| Persistent RepoPrompt MCP config | Makes the entry visible to standalone OpenCode | Unnecessary for RepoPrompt-launched sessions and creates mutable-config conflicts |

Homebrew remains a fallback only if the upstream Nix package is reproducibly unusable on Apple Silicon. Adopting it requires a new decision that reconciles ADR-016, removes the flake package and bridge atomically, and accepts weaker rollback guarantees. `pkgs.opencode` may be reconsidered when its version satisfies the ACP/UI/MCP compatibility checks.

## Consequences

- Commit `64de4d0` landed the tagged input, independent lock nodes, Tier 1 package, and `~/.local/bin/opencode` bridge.
- Package selection is host-platform-aware rather than hard-coded to `aarch64-darwin`.
- The tier file remains package-only; `llm-tools.nix` owns RepoPrompt GUI discovery.
- The bridge is store-managed under ADR-019 because it points to an immutable store binary. This differs from ADR-012's `mkOutOfStoreSymlink` shims for frequently edited checkout scripts.
- One activation atomically exposes the package and bridge, and a generation rollback can restore the earlier executable/link; follow the canonical [rollback procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-rollback).
- Binary rollback does not roll back OpenCode credentials/config/history, provider-side keys/billing/quotas, or RepoPrompt connection and model caches. Package removal, local logout, provider revocation, and RepoPrompt Sign Out remain separate transitions; follow the canonical [decommission procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-decommission).
- Promotion availability, price, privacy terms, and provider behavior remain live external facts and must be checked at use time. OpenCode Zen promotions and OpenRouter's free catalog are distinct credential and billing surfaces.
- RepoPrompt UI connection and direct MCP execution remain separate post-activation verification gates.

## Migration

- **Repository state complete:** Commit `64de4d0` landed the tagged input, independent lock nodes, Tier 1 package, and store-managed discovery bridge.
- **Rollout pending:** Before activation, complete the canonical [prerequisite/collision checks](../architecture/runbooks/opencode-repoprompt.md#opencode-prerequisites-collisions) and [verification/approval procedure](../architecture/runbooks/opencode-repoprompt.md#opencode-activation). Unresolved compatibility or executable collisions block activation.
- **Post-activation pending:** After approved activation, follow [provider onboarding](../architecture/runbooks/opencode-repoprompt.md#opencode-provider-onboarding), the [credential lifecycle](../architecture/runbooks/opencode-repoprompt.md#opencode-credential-lifecycle), and [RepoPrompt UI/MCP connection verification](../architecture/runbooks/opencode-repoprompt.md#opencode-repoprompt-connection). Initial verification remains read-only and must avoid full-access mode.

## Risks

- A stale `~/.opencode/bin/opencode` may outrank the managed bridge in RepoPrompt's degraded GUI environment; collision inspection is mandatory.
- An upstream release may stop building on Darwin, change ACP behavior, or alter its lock graph. Build before activation and revalidate RepoPrompt after either side upgrades.
- A cached model can disappear or become paid while remaining visible temporarily. Refresh and check current provider pricing, quotas, retention, and privacy terms before use.
- Credentials are intentionally mutable and survive Nix rollback. Removing the package is not credential revocation or data deletion.
- OpenCode runs with the user's OS authority. RepoPrompt's tool policy is not an operating-system sandbox, so initial validation must be read-only and avoid full-access mode.
