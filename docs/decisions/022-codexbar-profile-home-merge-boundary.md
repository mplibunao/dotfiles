# ADR-022: CodexBar profile-home merge boundary

**Status:** accepted
**Date:** 2026-08-21
**Amended:** 2026-08-27

## Context

CodexBar derives local token, cost, and session statistics by scanning Codex JSONL session files. RepoPrompt CE runs its bundled Codex against an isolated `CODEX_HOME` under `~/Library/Application Support/RepoPrompt CE/Codex/Release/home`, so a large share of this machine's Codex activity was invisible to CodexBar while its remote quota numbers stayed accurate. CodexBar 0.54.0 accepts alternate selectable homes through `codexProfileHomePaths` on the `providers[]` object whose `id` is `codex`; it scans the active home rather than aggregating every configured home.

On this machine, that array lives in `~/.config/codexbar/config.json`. CodexBar rewrites this mode-`0600` file whenever settings change, and its CLI can persist provider API keys there. Neither option in ADR-019 fits. A store-managed mapping would make the file read-only and replace app-owned fields. An out-of-store symlink to a tracked file would push credentials and generated state into git.

CodexBar later moved its effective writable config from the legacy path to `~/.config/codexbar/config.json`. This amendment updates path authority without changing ownership. The legacy file isn't a second target. Activation never copies, reconciles, or removes it.

The app also updates itself through Sparkle. When this decision was taken, the running bundle was 0.54.0 while the Homebrew receipt still recorded 0.17.0, so the cask declaration guarantees membership rather than a version.

## Decision

`dotfiles` owns exactly one value (the presence of RepoPrompt CE's Codex home in the Codex provider's `codexProfileHomePaths`) and reconciles it at Home Manager activation time.

- `nix/scripts/codexbar-config` (ADR-011) owns only the merge mechanics: fail-closed shape validation, a PID-recorded lock, a byte-for-byte backup, atomic replacement, and `codexbar config validate` as the write gate. It decides no paths and no policy.
- `nix/home/mp/modules/codexbar.nix` owns the policy: the literal config target and managed profile home, plus whether a running app defers.
- The helper reaches activation as a wrapped store copy in `home.packages` with `PATH` set outright, rather than the `~/.local/bin` shim of ADR-012. Activation runs with a minimal environment, and a helper that rewrites private JSON must not resolve `jq` from whatever the caller happens to expose.
- Everything else in that file stays CodexBar's: accounts, credentials, active source, preferences, and every other provider. That file never enters git or the Nix store, and nothing here claims it as a whole.
- Installation stays with the Homebrew cask (ADR-005, ADR-016). This decision does not change updater ownership.

## Alternatives considered

| Option | Why rejected |
|--------|--------------|
| GUI-only configuration | Not reproducible; the installed Codex page exposes no control for registering an existing profile home. |
| Store-managed or symlinked full JSON | A store mapping makes the live file read-only and replaces app-owned fields; a symlink to a tracked file lets credentials reach git. |
| Committing a redacted copy of the live file | Redaction is brittle and live state is not the canonical source. |
| Native include or overlay file | The installed build documents one complete config; no overlay exists to use. |
| `CODEXBAR_CONFIG` launchd override | Adds a second path boundary, and the helper treats such an override as a shadowed target. |

## Consequences

- The managed value converges on every switch, but the file it lives in is outside the store. `darwin-rebuild switch --rollback` cannot restore it; recovery comes from the timestamped backups under `~/.local/state/codexbar-config/backups/` or from `remove-managed-profile`.
- Activation is fail-closed. A malformed config, a shadowed target, duplicate Codex providers, or a wrong owner stops the switch without writing. A machine where CodexBar has never run has no config to merge into, so `mp.codexbar.enable` must stay off until the app has created its own skeleton once.
- A running CodexBar defers instead of failing: activation prints the supervised command to run after quitting the app, so an unrelated switch still completes.
- A machine with only the legacy `~/.codexbar/config.json` fails closed until CodexBar establishes the canonical XDG file. A candidate identical to the configured target isn't a shadow. A different existing launchd or default-XDG candidate blocks reconciliation. The helper also rejects any explicit `CODEXBAR_CONFIG` override.
- Unlike the ADR-012 shims, edits to `nix/scripts/codexbar-config` now need a rebuild to take effect. The packaged copy cannot use the synthetic test-state injection that `nix/tests/codexbar-config-test.sh` relies on.
- Only JSONL-derived statistics improve. Metadata CodexBar reads from Codex's SQLite state, including Fast and Priority attribution, stays incomplete because RepoPrompt CE's sibling `CODEX_SQLITE_HOME` has no equivalent mapping.
- CodexBar 0.54.1 includes the scope-safety fix from [PR #3132](https://github.com/steipete/CodexBar/pull/3132). After a profile switch, CodexBar hides any incompatible previous-profile token snapshot instead of rendering it under the new profile. Selecting a profile doesn't guarantee an immediate local token scan. Use Refresh when the selected profile has no current snapshot.

## Migration

Adding the module is not enough on its own: the first reconciliation is supervised. Quit CodexBar before running the approved switch. Confirm the backup and the invariant before relaunching the app, then select the new profile in the GUI. Removal reverses this order. With the app stopped, run `remove-managed-profile`. Confirm that the statistics drop back before removing the module in a later change. `nix/docs/gui-apps.md` carries the commands.

## Risks

- A self-update or cask update could change the schema. The shape check plus `codexbar config validate` abort and restore the backup; compare the running, receipt, and tap versions before any Homebrew operation, since a `brew upgrade --cask` from stale tap metadata can replace a newer self-updated bundle.
- CodexBar Settings could drop the managed path on save. Treat that as a compatibility signal and revisit this decision, rather than escalating to ownership of the whole file.
