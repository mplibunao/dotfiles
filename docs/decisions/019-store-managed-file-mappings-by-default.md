# ADR-019: Store-managed file mappings by default, out-of-store symlinks by exception

**Status:** accepted
**Date:** 2026-04-27

## Context

Home Manager supports two practical ways to map files from this repo into `$HOME`:

1. **Store-managed mappings** — `xdg.configFile` / `home.file` with normal in-flake sources. Files are copied into `/nix/store/...` at build time; the live symlink points at the frozen store copy. Edits to source files require `darwin-rebuild switch` to take effect.
2. **Out-of-store symlinks** — `config.lib.file.mkOutOfStoreSymlink`. Nix still creates and owns the symlink, but it points directly at the working tree. Edits to existing files take effect immediately; no rebuild needed.

At the time this ADR was adopted, the repo already used both patterns:

- Store-managed: `fish.nix` (originally), most program modules.
- Out-of-store: `nix-ops-tools.nix`, `cloudflared.nix`, `leaderkey.nix`, `karabiner.nix`.

ADR-009 made store-managed the default for Fish functions but left out-of-store as an unscoped "escape hatch". ADR-012 used out-of-store for operational scripts because edit→run feedback matters more than rebuild-time immutability there. A general rule prevents future modules from drifting in either direction by accident, and supersedes ADR-009 by promoting Fish authored **functions** to out-of-store under the criteria below. Fish authored **completions** stay store-managed because the dir layers in generated entries such as `mise.fish` that `mkOutOfStoreSymlink` cannot host (see Migration). `pnpm.fish` is the exception: Corepack owns pnpm, so Fish generates that completion from the active pnpm binary outside Nix.

## Decision

Use **store-managed mappings by default.**

Use `mkOutOfStoreSymlink` only when **at least one** of these is true:

1. The file is an executable or operational script where edit→run iteration matters more than rebuild-time immutability (e.g. `nix-ops-tools.nix`).
2. The file is actively written or mutated by an external GUI app or tool (e.g. `karabiner.nix`, `leaderkey.nix`).
3. The file is a shell helper or "config-as-code" iterated multiple times per week and the rebuild loop becomes a friction tax (e.g. Fish authored functions).
4. The mapping intentionally exposes a repo checkout as the source of truth for a tool that must observe changes immediately.

Every out-of-store mapping must include a short module comment naming which condition justifies it.

Do **not** use `mkOutOfStoreSymlink` to:

- Avoid staging new files with `git add` (flakes ignore untracked files regardless).
- Avoid rebuilds for ordinary config changes made rarely.
- Bypass Home Manager collision handling.

### Decision matrix

| Scenario | Mechanism | Rationale | Existing example |
|----------|-----------|-----------|------------------|
| Program has a HM module | `programs.<name>` | Type-checked, declarative | `programs.fish`, `programs.git`, `programs.kitty` |
| Static config under `~/.config` | `xdg.configFile` (store-managed) | Reproducible, rebuild-controlled | Generated `mise.fish` completion |
| Authored shell helper iterated often | `mkOutOfStoreSymlink` (single-dir, no `recursive`) | Edit / add / delete are all live | `fish.nix` functions |
| Authored dir that needs layered store entries | **Store-managed** with `recursive = true` | `mkOutOfStoreSymlink` + `recursive` does NOT compose with explicit layered entries (HM rejects with "Error installing file outside $HOME") | `fish.nix` completions (layers `mise.fish`) |
| Internal script iterated and run often | `mkOutOfStoreSymlink` shim | Edit→run loop matters | `nix-ops-tools.nix` |
| GUI app config the app rewrites | `mkOutOfStoreSymlink` (with `force` if needed) | Avoid fighting app-side writes | `leaderkey.nix`, `karabiner.nix` |
| Generated file from installed binary | Explicit `runCommand` derivation | Tied to package version | `mise.fish` completion |
| Secrets, auth tokens, machine-local state | Do not manage via HM | Should not enter the flake | SSH keys, gh hosts, gcloud auth |
| Config file that also receives auth tokens | HM **activation script** seeds static keys; file itself is unmanaged | File must be writable (store symlink is read-only, blocks `npm login`); auth token must not enter the world-readable Nix store or tracked repo; npm reads `~/.npmrc` in every context (interactive shell, launchd services, GUI apps) — unlike `NPM_CONFIG_*` env vars, which are absent from launchd/GUI processes that inherit an empty environment | `~/.npmrc` |

## Alternatives considered

| Option | Pros | Cons |
|--------|------|------|
| Store-managed for everything | Maximum reproducibility, atomic rollback of content, closure is self-contained | Slow iteration loop for scripts and shell helpers; edit→effect requires rebuild |
| Out-of-store for everything | Edit→effect is instant; fewer rebuilds | Less reproducible; closure is incomplete; branch checkouts silently change live config; rollback can't recover content |
| Store-managed by default, out-of-store by exception (chosen) | Keeps the declarative baseline; allows ergonomic exceptions where they make sense | Requires explicit judgment per module |

## Consequences

- New modules default to store-managed unless they meet a documented exception.
- Out-of-store modules must carry a comment naming the qualifying condition.
- `fish.nix` migrates **functions only** to `mkOutOfStoreSymlink` under condition 3 (authored functions iterated often). Authored completions and generated completions both stay store-managed.
- At adoption, the existing out-of-store modules (`nix-ops-tools`, `cloudflared`, `leaderkey`, `karabiner`) remained valid — they all matched conditions 1 or 2.
- `kokoro-tts.nix` remains store-managed — not iterated frequently, no external writer.
- `~/.npmrc` is a **documented exception**: npm writes auth tokens into that file, so it must be (a) writable — a store-managed symlink is read-only, blocking `npm login` — and (b) absent from the world-readable Nix store and tracked repo. The file is left unmanaged/local; its static config (`prefix`, `min-release-age`, `ignore-scripts`) is seeded by a Home Manager activation script in `llm-tools.nix`. The activation is idempotent and preserves all unmanaged lines (including auth tokens) on every rebuild.
- ADR-009 is superseded.

### Cons of `mkOutOfStoreSymlink` to acknowledge

- **Branch surprise:** `git checkout` to a branch where the source file doesn't exist → live symlink dangles until you check back.
- **Uncommitted edits work:** the file works on your machine before you commit; lose the working tree and you lose the file. Mitigated by committing regularly.
- **Rename → dangling symlink:** until next rebuild creates the new entry.
- **Rollback only flips link metadata:** `darwin-rebuild --rollback` doesn't restore yesterday's file contents (use `git` for content history).
- **Closure is incomplete:** copying the system closure to another machine without the dotfiles repo gives broken symlinks. Not relevant for single-machine setups.

These are acceptable for a single-machine setup with a regular committer. They become more significant for multi-machine or shared setups.

## Migration

### `fish.nix`

- `xdg.configFile."fish/functions"` → single-dir `mkOutOfStoreSymlink` pointing at `${dotfilesDir}/nix/home/mp/modules/fish/functions`. Drop `recursive = true` (no layered entries → full live behavior on add/edit/delete).
- `xdg.configFile."fish/completions"` stays **store-managed** with `recursive = true`. Attempted `mkOutOfStoreSymlink + recursive = true` empirically fails because HM rejects layered entries such as `xdg.configFile."fish/completions/mise.fish"` when the parent dir is mkOOS-managed (error: "Error installing file '.config/fish/completions/mise.fish' outside $HOME"). Authored completions (nix-ops, bvp, etc.) are operational and not iterated frequently — they don't meet condition 3 anyway. The `pnpm.fish` completion is generated outside Nix from the active Corepack-managed pnpm so completion behavior tracks repo-local pnpm pins instead of `pkgs.pnpm`.
- `pnpm.fish` refreshes at interactive shell startup, not on every directory change. That means a long-lived shell can keep the startup pnpm completion after `cd` into a repo with a different pnpm major. The tradeoff is intentional: completion drift is low risk, while a per-directory refresh hook would add shell-startup policy and performance complexity for little gain.
- Update top-of-file comment to point at this ADR and ADR-009 (legacy).

### `kokoro-tts.nix`

- Audited against the criteria. Not iterated frequently (daemon config). Stays **store-managed**. No change.

### `llm-tools.nix` / `~/.npmrc`

- `~/.npmrc` cannot be store-managed: npm writes its auth token into that file, making a read-only Nix-store symlink untenable, and the token must not enter the world-readable store or this tracked repo. The file is left unmanaged/local. A `seedNpmrc` Home Manager activation script strips the three managed keys (`prefix`, `min-release-age`, `ignore-scripts`) and re-appends canonical values on every rebuild, preserving auth-token lines and any other user content. The `NPM_CONFIG_*` env-var block is removed — env vars are invisible to npm started from launchd/GUI contexts (editor extensions, Husky hooks, LaunchAgents get an empty environment).

### Existing out-of-store modules at adoption

- `cloudflared.nix`, `leaderkey.nix`, `karabiner.nix`, `nix-ops-tools.nix` were unchanged when this ADR was adopted. They matched conditions 1, 2, or 4 at that time.

> **2026-08-26 retirement note:** `leaderkey.nix` was removed when Leader Key was retired (see the [retirement retrospective](../ledgers/2026-11-20-whispering-and-leader-key-retirement-retrospective.md)). It remains listed above as historical evidence of the original decision; `karabiner.nix` is the surviving app-rewritten-config example.

### Decision-log structure

- This ADR introduces the per-file ADR layout under `nix/docs/decisions/`, mirroring `claude-toolkit/docs/decisions/`. ADRs 001–018 were split into per-file format alongside this ADR (mechanically converted from the monolithic `09-decisions-log.md`, which is now a stub pointer). Future ADRs land directly in this directory.

## Risks

- First activation must transition `~/.config/fish/functions/` from per-file HM symlinks (previous store-managed + `recursive = true` setup) to a single parent-dir symlink. Mitigated with `force = true` on the new entry. **Caveat:** `force = true` removes the *entire* target directory, not only HM-tracked symlinks — assumes the dir contains only HM-managed entries (verified before adopting). Local `funcsave` files or manually-dropped scripts in that dir would be wiped. If activation still complains after `force`, `mv ~/.config/fish/functions ~/fish-functions-backup.$(date +%s)` first, then re-run `darwin-rebuild switch`.
- Live Fish function symlinks depend on the dotfiles checkout path (`${config.home.homeDirectory}/Projects/personal/dotfiles`) being stable. Moving the repo breaks the symlink until next switch.
- Loaded Fish functions in already-running shells need to be re-sourced (`functions --erase <name>; <name>` or new shell) to pick up edits.
- Generated Nix-owned completions such as `mise.fish` layer into the store-managed completions dir; if HM's collision handling regresses, the build fails fast (verified once during migration as "Error installing file outside $HOME" when completions were briefly mkOOS). Corepack-owned completions such as `pnpm.fish` are generated under Fish's user data completions directory instead.
- Future agents may over-interpret "out-of-store is OK now" as permission to flip everything. The criteria above are the gate.
