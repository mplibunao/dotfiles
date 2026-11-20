# ADR-026: Prebuilt CLIProxyAPI release, local dashboard checkout

**Status:** accepted
**Date:** 2026-11-04

## Context

CLIProxyAPI should run as a LaunchAgent on m5-mbp, with its usage dashboard beside it. The flake's nixpkgs pin (2026-07-11) has no `cliproxyapi` package. nixpkgs-unstable later added one (8.0.48 as of this decision). Building that expression on m5-mbp means a local link, and this machine's cctools ld crashes on those links. Upstream v8.0.53 also asks for Go 1.26, which the pin does not provide.

The dashboard repo `github.com/mplibunao/cli-proxy-dashboard` is private. A `git+ssh` flake input or `builtins.fetchGit` can only be locked where Mark's GitHub SSH key is loaded, and a pnpm package needs the lockfile and a dependency hash. Neither was available while adding this.

The management key and any proxy client keys must not enter git, the Nix store, or service logs. This repo has no sops or agenix installation. Executor and the surf gateway do not store service secrets. The local pattern for a secret that must survive as a normal file is the unmanaged mode-0600 `~/.npmrc` seed in `modules/llm-tools.nix`.

## Decision

1. Install CLIProxyAPI from the official release tarball, pinned at v8.0.53, the same way `packages/executor` and `packages/gh` install upstream binaries. `aarch64-darwin` is the Mac build. `x86_64-linux` exists so the same expression can be built and executed off the Mac.
2. Generate a v8 `config.yaml` with no secrets: loopback port 8317, `management.allow-remote: false`, empty `management.secret-key`, `oauth.auth-dir: "~/.cli-proxy-api"`, usage statistics on, a 3600 second usage-queue retention, and built-in session affinity (`routing.session-affinity: true`, `session-affinity-ttl: 1h`, `session-affinity-rebind-on: quota`). No `routing.strategy` is set, so the upstream default (`round-robin`) applies to sessions without a binding. The LaunchAgent reads `CLIPROXY_MANAGEMENT_KEY` from `~/.config/cli-proxy-api/secrets.env` (mode 0600) and passes it as `MANAGEMENT_PASSWORD`.
3. Do not package the dashboard. Run `pnpm run start` from a local checkout via a LaunchAgent, the same shape as `modules/surf-openai-gateway.nix`. The management key is the same file, exported as `CPA_MANAGEMENT_KEY`. Document the checkout and the move to `main` after PR #1 merges in the [runbook](../runbooks/cli-proxy-api.md).
4. Do not add a routing plugin. A one-shot login LaunchAgent publishes Claude Code's proxy route. See the amendments below. Codex's `config.toml` stays in claude-tooling.
5. `nix/scripts/cli-proxy-dashboard-setup` (ADR-011, shimmed like the other operational scripts) clones or updates the dashboard over SSH, checks out a ref, and runs `pnpm install` plus `pnpm run build` with Node 24's pnpm. It prints the checked-out SHA and does not read or write secrets. `init-secret` is a separate subcommand that may create the secrets file with `openssl rand -hex 32`, mode `0600`, without printing the value, and it refuses to overwrite an existing file. Browser OAuth logins stay manual, as in [ADR-021](021-opencode-upstream-flake-for-repoprompt-acp.md) point 7.

## Alternatives considered

- **nixpkgs `cliproxyapi`:** current enough (8.0.48) but not in the locked pin. Bumping the pin, or compiling an overlay on m5-mbp, pulls in the cctools link failure this host already works around.
- **`buildGoModule` of v8.0.53:** reproducible from source, and it needs Go 1.26 plus a local link on the Mac.
- **`git+ssh` flake input for the dashboard:** the simplest fetch once the repo is readable, and it makes every evaluation depend on the SSH key. It still needs a pnpm build. Revisit when the repo can be locked and its start script is known.
- **sops or agenix:** a real secret store, and it would be a new mechanism for one key. The unmanaged 0600 file matches what this repo already does.

## Consequences

- The Mac does not compile CLIProxyAPI. Upgrades are a version and two hashes, then a restart of the LaunchAgent.
- `~/.cli-proxy-api` is created mode `0700` and otherwise left alone, so OAuth logins survive rebuilds.
- `config.yaml` is a store symlink and contains no secrets. The service runs from a mode-0600 runtime copy under `~/.local/state/cli-proxy-api`, rebuilt on every start. Config changes go through the module.
- The dashboard is not rolled back by a Nix generation. Its code is whatever the checkout is.
- The dashboard listens on 8788. The surf OpenAI gateway keeps 8787. The module still warns if the two ports are set equal.
- `DATA_DIR` is `xdg.dataHome/cli-proxy-dashboard` (`~/.local/share/cli-proxy-dashboard`), created mode `0700` before launchd starts the job. The dashboard's own default is a relative `data` directory.

## Migration

New package, two Home Manager modules, and this runbook. No existing service changes its command. The surf gateway's port stays 8787.

## Amendment (2026-11-04): default client route

Point 4 originally left Claude Code and Codex off the proxy. They now default to it.

- `CLIPROXY_CLIENT_KEY` lives on the same mode-0600 secrets file as the management key. `init-client-key` appends it. `init-secret` writes only the management key.
- v8.0.53 has no client-key environment variable. Client keys are `access.api-keys`. The launch wrapper writes `~/.local/state/cli-proxy-api/runtime-config.yaml` mode `0600` from the store template plus that key, and the service uses that path. The store `config.yaml` stays empty of keys.
- One Home Manager LaunchAgent, `com.mp.cli-proxy-env` (`RunAtLoad`, not kept alive), reads the client key from the secrets file at login and runs `launchctl setenv` for `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and `CLIPROXY_CLIENT_KEY`. GUI apps and terminals both inherit the launchd session environment, so there is no fish export. Apps already open at first run need a relaunch. It is a plain `launchd.agents` entry because `launch-agent.nix` fails jobs that exit. The 2026-11-05 amendment adds a route setting and a command that turns the Claude route off and on.

## Amendment (2026-11-05): Claude on by default, Codex direct

Claude Code uses the proxy by default from every launch path on m5-mbp: RepoPrompt CE, Claude Desktop's Claude Code sessions, T3 Code, terminals and `ccy`. Codex uses its ChatGPT login unless a run opts in. One command turns the Claude route off and on.

- `com.mp.cli-proxy-env` follows a route setting, the file `~/.local/state/cli-proxy-api/claude-route`. It holds `on` or `off`, a missing file means on, and anything else is an error that publishes nothing. On, the agent publishes `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN` and `CLIPROXY_CLIENT_KEY`. Off, it unsets the two Anthropic variables and still publishes `CLIPROXY_CLIENT_KEY` for OpenCode's DeepSeek route. A Nix wrapper reads the key with the existing secrets-file reader and passes it to `nix/scripts/cli-proxy-env-launch`, which makes the `launchctl` calls. Home Manager doesn't manage the setting, so switches and rollbacks leave it alone.
- `claude-proxy-route on|off|apply|status` (`nix/scripts/`, linked into `~/.local/bin`) is the only writer of the setting. It re-runs the agent with `launchctl kickstart`, waits for the run, and reports what launchd publishes without printing a value. It's the way out when the proxy is down. Claude never falls back to direct on its own.
- `claude-launch` (claude-toolkit) reads the same file on every launch when `CLI_PROXY` is unset. `CLI_PROXY=0` or `1` sets the route for one launch. `codex-launch` stays direct unless `CLI_PROXY=1`. Home Manager links both into `~/.local/bin` from the claude-toolkit checkout. `ccy` is `claude-launch --dangerously-skip-permissions` and no longer goes through `clm`, so it loads Claude's ordinary MCP configuration.
- `claude-launch` and `claude-proxy-route` run from working checkouts and hardcode the setting's path and `http://127.0.0.1:8317`, so the module asserts that `xdg.stateHome` is `~/.local/state` and that the proxy listens on `127.0.0.1:8317`.
- While proxied, Claude Code loses claude.ai connectors, including in Claude Desktop's Claude Code sessions, as well as Remote Control and voice dictation. This loss is accepted. A session that needs those features runs `CLI_PROXY=0 claude-launch`.
- Codex Desktop's loss of ChatGPT-account plugins came from Codex's `cliproxy` provider, not from the Claude variables. claude-tooling PR #93 removed that provider from the synced Codex config, so Codex Desktop, RepoPrompt's Codex agent and plain `codex` use the ChatGPT login. The proxy keeps the Codex login so the dashboard can read limits.
- Rejected: a RepoPrompt custom Claude-compatible provider, which loses Claude-only behavior such as Auto permission mode; a wrapper or relauncher around RepoPrompt, which starts in too many ways to cover; and a fish export layer, which adds a second writer and can't clear stale values that RepoPrompt merges from its own environment.

Operating steps are in the [runbook](../runbooks/cli-proxy-api.md#claude-route).

## Amendment (2026-11-17): live dashboard on its own clone of main

Points 3 and 5 ran the dashboard from the checkout used for development, so whatever branch was checked out there went live on the next restart. The live dashboard now runs from its own clone, and development has its own proxy and dashboard.

- The LaunchAgent's checkout is `~/.local/share/cli-proxy-dashboard/app`, a separate git clone that only follows `main`. It runs `bun --env-file=config/production.env src/server/index.ts`. A git worktree was rejected: worktree cleanup treats a worktree on a merged branch as finished work, and git can't check out `main` in two worktrees at once.
- `cli-proxy-dashboard-setup` deploys `main` to that clone. It fast-forwards to `origin/main`, builds, and restarts the LaunchAgent. It refuses a clone with local changes or on another branch, and `--ref` is gone.
- Feature switches such as `SOONEST_RESET_ROUTING` live in the dashboard repo's `config/production.env`, so changing one takes a dashboard commit and a deploy, with no Nix switch. The plist sets none of them, because a variable already in the environment overrides the file. Bun ignores a missing `--env-file`, so activation refuses to switch without that file.
- Development uses the dashboard's `pnpm dev`: a second CLIProxyAPI process on port 8318 with its own logins, and a second dashboard on 8789. Only one dashboard may read a proxy, because the proxy deletes usage records once a dashboard reads them and the routing controller writes priorities into the proxy. `CLI_PROXY=dev claude-launch` sends one Claude Code session there.

## Risks

- A newer CLIProxyAPI might rewrite `config.yaml` on startup. The Linux check for v8.0.53 did not. If a later release does, point `--config` at a mode-0600 copy outside the store and keep secrets out of that copy's logged output.
- `MANAGEMENT_PASSWORD` is accepted for localhost while `allow-remote` is false in v8.0.53. The listener is also loopback. If a future release treats that variable as permission to leave the machine, stop passing it and inject the key into a private runtime config instead.
- `pnpm run start` is still the production command until the dashboard README says otherwise. `CPA_BASE_URL`, `CPA_MANAGEMENT_KEY`, `HOST`, `PORT`, and `DATA_DIR` match `src/server/config.ts` on PR #1.
- The dashboard checkout is not pinned by Nix. It follows `main`, and `cli-proxy-dashboard-setup` prints the deployed SHA.
