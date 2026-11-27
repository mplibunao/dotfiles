# OpenCode in RepoPrompt CE

Canonical operator procedure for the Nix-managed OpenCode ACP CLI in RepoPrompt CE. Nix owns the pinned executable and `~/.local/bin/opencode` discovery link. The operator owns authentication; OpenCode owns mutable credentials/config/data; RepoPrompt owns its connection, model catalog, role selections, and process-ephemeral MCP policy.

See [ADR-021](../../decisions/021-opencode-upstream-flake-for-repoprompt-acp.md).

## Guardrails

- Follow the [rules in `AGENTS.md`](../../../AGENTS.md#rules) for every switch.
- Do not put API keys, OAuth records, provider/model defaults, or OpenCode auth/config paths in Nix or Git.
- Do not add a login wrapper, external OpenCode plugins, a daemon, or a persistent RepoPrompt MCP entry for normal use. Interactive provider selection, browser OAuth, and secret entry are steps only the operator performs, and they cannot be safely scripted. This runbook is the written procedure the [non-declarative steps rule](../../../CODING_STANDARDS.md#non-declarative-steps) asks for when a person has to do a step, and the upstream CLI is the operational mechanism.
- Run initial checks in a disposable, non-sensitive repository with a read-only task. Do not select full-access mode.
- Current promotions, prices, quotas, retention, and privacy terms are external state; verify them before using proprietary or sensitive code.

<a id="opencode-prerequisites-collisions"></a>

## 1. Prerequisites and collision checks

Record the installed RepoPrompt CE version and confirm **Settings → CLI Providers** contains an **OpenCode CLI** card with ACP Connect/Test Connection behavior:

```bash
brew info --cask repoprompt/repoprompt-ce/repoprompt-ce
mdls -raw -name kMDItemVersion "/Applications/RepoPrompt CE.app"
```

If the card is absent, stop. Upgrade or build RepoPrompt CE as a separate, explicitly approved prerequisite; do not add provider plugins or configuration workarounds.

Before activation, inspect executable collisions and existing OpenCode config without modifying it:

```bash
type -a opencode 2>/dev/null || true
ls -ld "$HOME/.local/bin/opencode" "$HOME/.opencode/bin/opencode" 2>/dev/null || true
ls -l "$HOME/.config/opencode/opencode.json" "$HOME/.config/opencode/opencode.jsonc" 2>/dev/null || true
project_root="/absolute/path/to/intended/project"
find "$project_root" -maxdepth 2 \( -name opencode.json -o -name opencode.jsonc -o -name .opencode \) -print
```

Set `project_root` to the explicit project that will be used for initial verification; do not inspect whichever directory happens to be current. RepoPrompt may prefer `~/.opencode/bin/opencode` over the managed `~/.local/bin` bridge when GUI shell enrichment fails. The intended state is one managed executable and no unintended `~/.opencode/bin/opencode`.

Identify the owner of every path from `type -a` and both fixed hints before changing it. Inspect `ls -l` and `readlink` output, then match the resolved prefix and package inventory to Homebrew (`brew --prefix` / `brew list`), npm (`npm prefix -g` / `npm ls -g --depth=0`), Bun’s global package inventory, the upstream installer under `~/.opencode`, Nix, or a manual file/link. Record the owner and exact package/formula name. Uninstall or disable a managed competitor through that package manager or installer; do not move files out from under its database. Move only a manual file or symlink to a unique timestamped backup outside the searched names. Never use Home Manager `force = true` to hide a collision.

<a id="opencode-activation"></a>

## 2. Verify, then request activation approval

Work from the root of the checkout that holds the change, because the commands here use paths relative to it. [Switching from a branch](../command-ladder.md#switching-from-a-branch) says what to check before you check out a branch in the live checkout. First inspect the OpenCode lock node:

```bash
nix flake metadata --json | jq '.locks.nodes.opencode'
```

Then run the [command ladder](../command-ladder.md) through the build, and inspect the closure it left in `./result`:

```bash
nix path-info -rsSh ./result | grep -i opencode
```

Then run the ladder's [level 3 dry-run](../command-ladder.md#level-3-dry-run) and record its output. On this host it needs root, so it needs `sudo` and its own approval.

Review formatter changes, the OpenCode lock node, the built closure, and collision checks. Only after these checks, including the dry-run, pass and the user approves the switch, run the [level 4 apply](../command-ladder.md#level-4-apply) from that checkout. Authentication starts only after this approved activation exposes the pinned CLI.

<a id="opencode-executable-verification"></a>

## 3. Verify the activated executable

```bash
uname -m
type -a opencode
ls -l "$HOME/.local/bin/opencode"
ls -l "$HOME/.opencode/bin/opencode" 2>/dev/null || true
readlink "$HOME/.local/bin/opencode"
file -L "$HOME/.local/bin/opencode"
"$HOME/.local/bin/opencode" --version
"$HOME/.local/bin/opencode" acp --help

env -i \
  HOME="$HOME" \
  USER="$USER" \
  PATH="$HOME/.local/bin:/usr/bin:/bin" \
  opencode acp --help
```

Expected: Apple Silicon/`arm64`, the version named by the `opencode` tag in `flake.nix`, a `.local/bin` link into `/nix/store`, no unintended `~/.opencode/bin/opencode`, and successful ACP help in both normal and minimal GUI-like environments.

<a id="opencode-provider-onboarding"></a>

## 4. User-run provider authentication

The operator—not an agent—chooses providers and completes browser OAuth or secret entry. Follow the [credential commands and lifecycle](#opencode-credential-lifecycle) reference to log in and confirm configured provider names without exposing secrets. Re-running login adds or replaces one provider credential; multiple authenticated providers may coexist. Never paste credentials into an agent transcript.

### Choosing providers

1. Check the current official catalog and provider terms at rollout time.
2. Start with **OpenCode Zen** only when Zen's live catalog contains the desired promotion. Zen model IDs use the `opencode/<model-id>` namespace and may abstract the underlying inference provider.
3. **OpenRouter is separate from OpenCode Zen.** Its free catalog requires an OpenRouter credential and has its own pricing, limits, billing, retention, and privacy terms.
4. Add OpenRouter, NVIDIA, OpenAI/ChatGPT, GLM/Z.AI, or other supported providers later as needed; credentials can coexist.
5. Treat a “free,” “stealth,” or zero-price label as temporary. Verify provider-side usage and billing after a real test.

Do not encode a provider/model default in Nix and do not install external plugins for this integration.

<a id="opencode-deepseek-proxy"></a>

### DeepSeek through CLIProxyAPI

`modules/llm-tools/opencode.jsonc` points the `deepseek` provider at the local proxy (`baseURL` `http://127.0.0.1:8317/v1`, `apiKey` `{env:CLIPROXY_CLIENT_KEY}`), so DeepSeek usage shows in the proxy's records. RepoPrompt CE and T3 Code both launch `opencode acp` and use this same config; nothing changes in either app. Models are `deepseek/deepseek-v4-pro` and `deepseek/deepseek-flash`. Add the DeepSeek key to the proxy first: [DeepSeek for OpenCode](cli-proxy-api.md#deepseek-for-opencode).

1. A key saved by `opencode providers login` overrides `options.apiKey` in the pinned OpenCode (`packages/core/src/model-resolver.ts` at v2.2.5 drops the config `apiKey` when a stored credential exists), and an exported `DEEPSEEK_API_KEY` can do the same. A direct key would send traffic around the proxy. Log out of DeepSeek and confirm it is not listed:

   ```fish
   opencode providers logout deepseek
   opencode providers list
   set -q DEEPSEEK_API_KEY; and echo 'DEEPSEEK_API_KEY is set in this shell; remove it from your fish config'
   ```

2. After the switch, quit and reopen RepoPrompt CE and T3 Code. Each `opencode acp` process reads the config at launch, and a GUI app started before the env agent ran lacks `CLIPROXY_CLIENT_KEY` (`launchctl kickstart gui/(id -u)/com.mp.cli-proxy-env`, then relaunch it).
3. Test, then look for the call in the dashboard at <http://127.0.0.1:8788>:

   ```fish
   opencode run -m deepseek/deepseek-flash 'say ok'
   ```

### Roll back to direct DeepSeek

Do the client steps first, in this order, so no app keeps sending DeepSeek requests to a proxy that has lost its key:

1. In `modules/llm-tools/opencode.jsonc`, remove `baseURL` and `apiKey` from the `deepseek` provider's `options`.
2. Switch, following the [command ladder](../command-ladder.md#level-4-apply).
3. Quit and reopen RepoPrompt CE and T3 Code. Each `opencode acp` process reads the config at launch, so an app that was already running keeps the proxy settings.
4. Restore direct authentication with `opencode providers login` ([credential lifecycle](#opencode-credential-lifecycle)). Without its own DeepSeek key, OpenCode has nothing to send to DeepSeek.

Then remove the proxy's key and restart the proxy, as [DeepSeek for OpenCode](cli-proxy-api.md#deepseek-for-opencode) describes.

<a id="opencode-repoprompt-connection"></a>

## 5. Connect and select models in RepoPrompt

After login:

1. Confirm configured provider names using the [credential commands and lifecycle](#opencode-credential-lifecycle) procedure; record names only.
2. Quit and reopen RepoPrompt CE so it sees the activated filesystem state.
3. Open **Settings → CLI Providers → OpenCode CLI**.
4. Use **Connect** or **Test Connection** to force live ACP preflight and model discovery. RepoPrompt may poll on roughly a five-minute cadence, but Test Connection is the explicit refresh after login, logout, provider changes, promotions, or upgrades.
5. Require at least one current model, then run one read-only Agent Mode prompt in a disposable repository.
6. In RepoPrompt's model-role settings, optionally assign discovered models to explore, engineer, pair, or design. Keep role selection in RepoPrompt; do not create Nix defaults. Role assignment is post-rollout configuration, not an activation requirement.

For the boundary between RepoPrompt **Sign Out**, local OpenCode credentials, and provider access, follow [Credential commands and lifecycle](#opencode-credential-lifecycle).

### Direct MCP verification

Use `agent_manage.list_agents` and copy a returned compound model ID beginning with `openCode:` verbatim. The first colon separates RepoPrompt's provider kind; later colons can be part of the raw OpenCode model value. Do not construct or split the ID.

Start one read-only run with that exact ID, then wait/poll it to completion. If an interaction is pending, inspect and explicitly accept or decline it; never auto-approve unknown access. A discovered model is not sufficient evidence—require a real response. Treat `agent_run.start` as non-idempotent: if its response is lost, inspect sessions before retrying.

<a id="opencode-credential-lifecycle"></a>

## 6. Credential commands and lifecycle

Pinned `v2.2.5` provides one credential surface; `auth` aliases the canonical `providers` command:

| Action | Canonical command | Alias |
|---|---|---|
| Login | `opencode providers login` | `opencode auth login` |
| List configured providers | `opencode providers list` | `opencode auth list` |
| Remove a local credential | `opencode providers logout [provider]` | `opencode auth logout [provider]` |

For logout, omitting `[provider]` opens the interactive provider picker; supplying it removes that provider's local OpenCode credential directly. Local logout does not revoke an upstream API key or OAuth grant: provider-side revocation is a separate required transition when removing access. RepoPrompt **Sign Out** only clears RepoPrompt-side connection, polling, and model state. Nix rollback and package removal do not remove local credentials or revoke provider access. The OpenCode TUI `/connect` command remains an alternate management surface.

OpenCode stores credentials in `${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json` and should create the file with owner-only permissions. Check metadata without printing contents:

```bash
auth_file="${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json"
[ ! -e "$auth_file" ] || stat -f '%Su %Sp %N' "$auth_file"
```

- Generate and revoke keys at the provider. Never store them in this repository, Nix expressions, or the Nix store.
- Rotate by creating a replacement credential, logging in, refreshing/testing RepoPrompt, verifying a real run, and only then revoking the old provider key.
- If ownership or permissions become broader than user-only, stop using the credential, restore `0600`, identify the writer, and rotate it.
- Do not hand-edit `auth.json` without a protected backup. Do not delete other providers or non-credential session/history/database data during rotation.

<a id="opencode-ephemeral-mcp"></a>

## 7. Ephemeral RepoPrompt MCP default

Normal RepoPrompt launches inject `OPENCODE_CONFIG_CONTENT` for the session. That process-local overlay supplies the RepoPromptCE MCP entry, managed mode, permissions, and timeout. It leaves global and project OpenCode config unchanged.

Do not use RepoPrompt's persistent OpenCode MCP install control for this workflow. If `mcp.RepoPromptCE` already exists persistently:

1. Back up `~/.config/opencode/opencode.json` or `.jsonc` with permissions no broader than the original.
2. Remove only `mcp.RepoPromptCE`; preserve every other provider, agent, and MCP entry.
3. Validate the remaining JSON/JSONC and restart RepoPrompt.
4. Confirm a normal RepoPrompt launch still receives the ephemeral entry.

Never delete the whole OpenCode config directory to fix one MCP entry.

<a id="opencode-troubleshooting"></a>

## 8. Troubleshooting

| Symptom | Action |
|---|---|
| RepoPrompt reports the wrong executable/version | Inspect `~/.opencode/bin/opencode`, `type -a opencode`, and the `.local/bin` target. Identify each owner from its target/prefix and package inventory; uninstall or disable managed competitors through their owner, and move only manual files/links. |
| CLI missing in RepoPrompt | Verify the activated bridge and minimal-environment ACP check, restart RepoPrompt, then check installed RepoPrompt provider support. |
| `acp --help` fails | Treat the version as incompatible; do not authenticate or continue rollout. |
| No models | Confirm configured providers per the [credential-lifecycle procedure](#opencode-credential-lifecycle), provider status, global/project config, and current catalog; then Test Connection again. |
| Models list but prompts fail auth | Repeat provider login through the [credential-lifecycle procedure](#opencode-credential-lifecycle) and require a real read-only run; discovery alone is insufficient. |
| Free/promotional model vanished or ID is stale | Test Connection, rerun `list_agents`, and copy a current ID verbatim. Do not retain a stale role/default. |
| Behavior differs by repository | Reproduce in a clean workspace, then inspect project `opencode.json`, `.jsonc`, and `.opencode` entries. |
| Persistent MCP conflict | Back up config and remove only `mcp.RepoPromptCE`; keep normal operation ephemeral. |
| Permission prompt | Explicitly accept or decline the advertised interaction; never auto-approve. |
| Run hangs | Poll first, then cancel that specific session. |
| Credential permissions drift | Stop, restore owner-only permissions, identify the writer, and rotate credentials. |
| Failure after RepoPrompt/OpenCode upgrade | Treat ACP version pairing as the first suspect and rerun both UI and direct MCP checks. |

## 9. Upgrade, rollback, and decommission

<a id="opencode-upgrade"></a>

### Upgrade

The source URL continues to name the configured OpenCode version tag until it is edited, so an intentional release upgrade starts with a tag change. Git tags can move, however: any lock update may change the locked revision or `narHash` even when the tag text is unchanged. Review those locked values on every update. To intentionally upgrade:

1. Review the target upstream tag, Darwin output, changelog, and lock graph.
2. Edit the OpenCode tag in `flake.nix`.
3. Run `nix flake update opencode` only.
4. Empty `nodeModulesHashes` in `packages/opencode/default.nix` and build. If the build fails with a hash mismatch for `opencode-node_modules`, add the reported `got:` hash for that platform and build again ([ADR-025](../../decisions/025-opencode-node-modules-hash-override.md)).
5. Review `flake.lock`, build, dry-run, and recheck collisions.
6. Obtain explicit approval before activation.
7. After activation, rerun RepoPrompt Test Connection and one direct `agent_run` smoke test.

After any RepoPrompt CE cask upgrade, perform the same UI and direct MCP revalidation even when the OpenCode pin did not change.

<a id="opencode-rollback"></a>

### Rollback limits

With separate explicit approval, the operator may run:

```bash
sudo darwin-rebuild switch --rollback
```

This can restore the previous executable and discovery link. It does **not** restore or remove OpenCode credentials/config/history, provider keys/billing/quotas, project config, or RepoPrompt connection/model caches. Restart RepoPrompt after rollback and refresh or Sign Out as appropriate.

<a id="opencode-decommission"></a>

### Decommission

Treat these as separate reviewed actions:

1. While the managed executable is still available, complete local credential removal and upstream revocation through [Credential commands and lifecycle](#opencode-credential-lifecycle).
2. Use RepoPrompt **Sign Out** to clear RepoPrompt-owned state.
3. Remove only a persistent `mcp.RepoPromptCE` entry if one exists, following the [persistent-entry cleanup procedure](#opencode-ephemeral-mcp).
4. Only then activate an approved Nix generation that removes the input, Tier 1 package, and discovery link.
5. Preserve unrelated OpenCode config and non-credential session/history/database data unless the user explicitly approves destroying it.
