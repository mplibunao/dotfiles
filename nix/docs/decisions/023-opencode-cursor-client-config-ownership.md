# ADR-023: Exact-file ownership for OpenCode and Cursor client configuration

**Status:** accepted
**Date:** 2026-09-26

## Context

The Executor gateway needs persistent client entries in standalone OpenCode and Cursor. OpenCode's authentication and per-session choices must remain writable and local. Cursor already has a global RepoPrompt MCP entry that must remain direct. Home Manager needs a narrow ownership boundary so the gateway configuration is reproducible without taking over either client's directory or mutable state.

[ADR-021](021-opencode-upstream-flake-for-repoprompt-acp.md) point 4 kept all ordinary OpenCode configuration outside Nix. That point prevents the exact-file mapping needed for Executor. Point 5's process-ephemeral RepoPrompt MCP overlay for OpenCode remains applicable.

## Decision

Home Manager store-manages exactly two client configuration files: OpenCode's `~/.config/opencode/opencode.jsonc` and Cursor's global `~/.cursor/mcp.json`. This decision supersedes only ADR-021 point 4. ADR-021 point 5 remains in force: OpenCode has no persistent `mcp.RepoPromptCE` entry. ADR-021 point 6 remains in force: provider, model, and role choices for each session remain operator-owned in OpenCode and RepoPrompt.

The OpenCode file is mapped at its separate P3 migration gate. Its non-secret model defaults and DeepSeek provider settings remain, but its API key moves to the local OpenCode auth store before the managed mapping is activated. Home Manager leaves the `~/.config/opencode` directory, `~/.local/share/opencode/auth.json`, sessions, history, project configuration, and credentials outside its scope.

The Cursor file retains the existing RepoPrompt entry with the same parsed JSON values and adds only the `executor` entry specified by the [Executor gateway plan](../../../../ai/claude-toolkit/docs/exec-plans/active/2026-09-23-executor-mcp-gateway.md#cursor). Home Manager leaves the `~/.cursor` directory and other Cursor preferences outside its scope. RepoPrompt stays a direct MCP connection, separate from Executor.

Both mappings use ordinary store-managed `home.file` or `xdg.configFile` sources under [ADR-019](019-store-managed-file-mappings-by-default.md). Neither mapping uses `force = true` to bypass a local-file collision.

## Alternatives considered

| Option | Tradeoff |
|---|---|
| Keep both files wholly local | Allows local edits, but gateway entries drift outside the Nix generation and rollback boundary. |
| Map client directories | Captures unrelated preferences, authentication, and app-owned state. |
| Use out-of-store symlinks | Makes a checkout edit affect live client configuration without a reviewed activation. |

## Consequences

- Cursor's global MCP file has one versioned source and preserves its direct RepoPrompt route alongside Executor.
- OpenCode's exact-file mapping can land at its credential-migration gate without changing operator-owned authentication or per-session selection.
- Changes to either managed file require a build and approved Home Manager activation to reach the live client.

## Migration

For Cursor, back up the existing regular `~/.cursor/mcp.json` privately with its mode preserved. Verify the versioned RepoPrompt entry equals the backed-up entry as parsed JSON. Build the configuration without applying it. Only after approval, move the regular file to the private rollback location immediately before the user runs `darwin-rebuild switch`; verify the resulting store symlink and both MCP entries. Restore the regular file after a failed activation only after confirming the target is outside Home Manager ownership.

At OpenCode's P3 gate, follow the [Executor gateway plan's OpenCode credential migration](../../../../ai/claude-toolkit/docs/exec-plans/active/2026-09-23-executor-mcp-gateway.md#opencode) before mapping `opencode.jsonc`. That migration includes a real authenticated prompt before activation. The OpenCode exact-file mapping was activated on 2026-10-28. The managed file and a standalone Executor read passed verification.

## Risks

- Home Manager will reject the existing regular Cursor file until the approved activation moves it aside. Moving it during preparation would disrupt the current client.
- A later local Cursor edit to its managed MCP file will need to be made in the versioned source and activated through Home Manager.
- Cursor's installed-build timeout and model-visible output still require direct pilot checks before browser approval can be declared usable.
