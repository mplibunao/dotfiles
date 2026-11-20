# ADR-020: Node.js via mise (supersedes ADR-004)

**Status:** accepted
**Date:** 2026-05-29

## Context

[ADR-004](004-nodejs-via-fnm.md) chose fnm for Node version management. Since
then mise (formerly rtx) entered the stack for polyglot, repo-local tool
management — it is installed in tier2 and activated for interactive shells in
`fish.nix` (`mise activate fish`). Running fnm alongside it meant two `cd` hooks
and a Node-only tool that mise already subsumes.

## Decision

Use **mise** for Node.js version management and drop fnm.

Reasons:

1. mise is a functional superset of fnm for Node: official prebuilt binaries,
   auto-switch on `cd` (via the already-present `mise activate` hook), and it
   reads `.nvmrc` / `.node-version` once idiomatic version files are enabled.
2. One tool and one config (`mise.toml`) cover Node plus other repo-local
   toolchains, env vars, and tasks — the reason mise is in the stack at all.
3. Removes a redundant shell hook: fnm's `--use-on-cd` is no longer needed now
   that `mise activate` already runs on every `cd`.

## Idiomatic version files

mise 2025.10+ ships idiomatic version files (`.nvmrc`, `.node-version`) **off**
by default. We re-enable them for node via the
`MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=node` env var (set in
`home.sessionVariables`), not in `config.toml`, so the global
`~/.config/mise/config.toml` stays writable for the imperative
`mise use -g node@X` workflow.

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Keep fnm alongside mise | No change | Two `cd` hooks; fnm is a Node-only subset of what mise already does |
| mise (chosen) | One tool for every repo-local toolchain; superset of fnm for Node | `.nvmrc` support needs an opt-in setting |
| Nix-native node | Reproducible | Heavier closures; no per-repo `.nvmrc` switching |

## Consequences

- fnm removed from `node.nix`; Node now comes from mise (tier2) + `mise activate`
  (interactive) and mise's shims dir on `PATH` (non-interactive, via common.nix).
- The global default Node is pinned **imperatively** with `mise use -g node@X`
  (writes `~/.config/mise/config.toml`), not in Nix. mise downloads Node
  imperatively, so it is never reproducible via Nix regardless; pinning it in a
  Nix-managed file would make that file a read-only symlink and break
  `mise use -g`.
- Corepack still owns the repo's pnpm/yarn version (pinned by each repo's
  `package.json` `packageManager` field). `node.nix` installs its shims into the
  active Node prefix (once per version) and exposes that prefix for
  non-interactive shells, matching the old `fnm env` behavior. The corepack
  binary is resolved from the Node prefix (bundled, Node <= 24) or the explicit
  npm-global path `~/.npm-global/bin/corepack` (Node 25+, see Risks); the
  interactive `pnpm` and `yarn` wrappers self-heal by enabling Corepack on demand
  when the tool is missing after a mid-shell Node switch.
- Node versions now live in `~/.local/share/mise/installs/node` (was
  `~/.local/share/fnm`).
- Global npm packages still live outside the flake (unchanged from ADR-004).

## Migration

1. `mise use -g node@24` — install + pin the global Node (replaces
   `fnm default`); run before the switch so there is no window without Node.
2. `sudo darwin-rebuild switch` to drop fnm.
3. Restart the shell; verify `which node` resolves under
   `~/.local/share/mise` (or a `.nvmrc`-pinned version), not
   `~/.local/state/fnm_multishells`.

## Risks

- Idiomatic-file enablement is an env var exported through managed shells.
  GUI/launchd contexts that invoke mise's shims outside a shell will not see it
  — the same scope limitation the fnm shell-init setup had.
- **Node 25+ drops bundled Corepack.** `node.nix` prefers the active Node
  prefix's bundled corepack; on Node 25+ that is absent, so it falls back to the
  npm-global corepack at the **explicit** path `~/.npm-global/bin/corepack`.
  Provide one with `npm i -g corepack` — npm stays bundled with Node, so this is
  the recommended bootstrap. The fallback is by explicit path, not a `PATH`
  lookup, because mise's shims dir is early on `PATH` and ships a `corepack` shim
  that under Node 25+ would dispatch to the active Node (where corepack is
  absent). Not via Nix (would pull a nodejs into the closure) nor mise (no
  registry entry). Until a corepack exists the guard fails safe and pnpm/yarn
  simply will not appear. Revisit before moving the global mise Node to 25+. This
  is a Corepack *bootstrap* concern, not a reason to move pnpm/yarn into mise.
- The `pnpm`/`yarn` self-heal guards use `command -q` (name resolution), chosen
  to avoid a `mise where node` call on every invocation. This assumes no
  standalone `pnpm`/`yarn` binary shadows the active Node's Corepack shim.
  Never `pnpm setup` a standalone pnpm under `PNPM_HOME`: that would defeat
  both the self-heal and Corepack ownership, since the pnpm *binary* is owned by
  Corepack via the active mise Node. `PNPM_HOME` (`~/Library/pnpm`) holds only the
  pnpm store and global-package bins. pnpm 11 links those global bins into
  `$PNPM_HOME/bin` (`~/Library/pnpm/bin`), so `node.nix` puts that subdir on
  `PATH`, not `$PNPM_HOME` itself. (The earlier "`PNPM_HOME` is on `PATH`"
  assumption was wrong and hard-errored the first real `pnpm i -g`.)
- A freshly-installed Node version switched into mid-shell has no Corepack shims
  yet; the interactive `pnpm`/`yarn` wrappers self-heal on first use.
  Non-interactive one-shot shells (`fish -c`) lack those wrappers, so a brand-new
  version may need one prior interactive shell (or a manual `corepack enable`).
