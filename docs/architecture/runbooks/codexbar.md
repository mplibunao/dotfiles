# CodexBar profile home

How to operate `mp.codexbar.enable`, which keeps RepoPrompt CE's Codex session home available as an alternate profile in CodexBar. [ADR-022](../../decisions/022-codexbar-profile-home-merge-boundary.md) records why the module manages one value in CodexBar's own config. This runbook has the commands. The module is [`modules/codexbar/default.nix`](../../../modules/codexbar/default.nix), and the helper it installs is [`scripts/codexbar-config`](../../../scripts/codexbar-config).

CodexBar counts only the active Codex session home, and RepoPrompt CE runs its bundled Codex against an isolated one. That isolated home is the profile home, at `~/Library/Application Support/RepoPrompt CE/Codex/Release/home`. Activation adds the profile home to the `codexProfileHomePaths` array of CodexBar's writable config, `~/.config/codexbar/config.json`, and changes nothing else in the file. It doesn't combine the normal and RepoPrompt homes into one total. You choose the profile in CodexBar.

## What activation does

After Home Manager links the generation, activation runs `codexbar-config reconcile --defer-if-running`.

- It fails closed. A malformed config, a shadowed target, duplicate Codex providers, or a wrong owner stops the switch without writing.
- A running CodexBar defers the write instead of failing the switch. Activation prints the command to finish the job ([Finishing a deferred reconciliation](#finishing-a-deferred-reconciliation)).
- Before each write, the helper copies the config byte for byte into the backup folder. If the CodexBar CLI rejects the new file, the helper restores the original and keeps the backup.
- It refuses to write as root, so it never leaves root-owned private state. Run `reconcile` and `remove-managed-profile` as yourself, not with `sudo`.

## Before the first switch

On a machine where CodexBar has never run, there is no config to merge into and activation fails closed. Launch the app once so it writes its own skeleton, or leave `mp.codexbar.enable = false` until then. The config at `~/.config/codexbar/config.json` must exist before reconciliation. Activation doesn't copy, rename, reconcile, or delete the legacy `~/.codexbar/config.json`.

Supervise the first reconciliation:

1. Quit CodexBar.
2. Switch, which needs approval ([`AGENTS.md`](../../../AGENTS.md)).
3. Run the read-only check below. Confirm it reports `status=unchanged`, and look for the backup under `~/.local/state/codexbar-config/backups/`.
4. Relaunch CodexBar and select the new profile.

## Checking versions and the config

CodexBar updates itself through the Sparkle updater, so the installed bundle can be newer than the Homebrew receipt. Compare all four versions before any Homebrew operation on this cask, because a `brew upgrade --cask` driven by stale tap metadata can replace a newer bundle:

```bash
defaults read /Applications/CodexBar.app/Contents/Info CFBundleShortVersionString
codexbar --version
brew list --versions --cask codexbar
brew info --json=v2 --cask codexbar | jq -r '.casks[0].version'
```

After any in-app or cask update, revalidate with the read-only check. It reports the same four versions and validates the schema without changing the config:

```bash
codexbar-config check \
    --config "$HOME/.config/codexbar/config.json" \
    --profile-home "$HOME/Library/Application Support/RepoPrompt CE/Codex/Release/home"
```

The `status` field is `unchanged` when the profile home is already in the config and `change-required` when it's missing.

## Finishing a deferred reconciliation

When CodexBar is running, activation prints `status=deferred` and the command to run. Quit CodexBar first, then run it:

```bash
codexbar-config reconcile \
    --config "$HOME/.config/codexbar/config.json" \
    --profile-home "$HOME/Library/Application Support/RepoPrompt CE/Codex/Release/home" \
    --backup-dir "$HOME/.local/state/codexbar-config/backups"
```

## Removing the managed profile

To hand the value back to CodexBar temporarily, quit the app and run the same command with `remove-managed-profile` in place of `reconcile`. It removes that one path and nothing else.

The next switch reconciles the path back into CodexBar's configuration unless `mp.codexbar.enable` is false. To remove it permanently:

1. With CodexBar quit, run `remove-managed-profile`.
2. Confirm that the statistics drop back.
3. Disable the option or remove the module in a reviewed change, before the next approved switch.

## Recovery

CodexBar's config isn't in the Nix store or in Git, so `darwin-rebuild switch --rollback` restores the module, not the file. Before it writes, the helper stores a byte-for-byte copy under `~/.local/state/codexbar-config/backups/`, and nothing prunes them. Those backups are the only recovery source for this file. A backup's name combines the config file name, a UTC timestamp, and `.bak` with a random suffix.

To restore one, quit CodexBar, copy the chosen backup over `~/.config/codexbar/config.json`, and run the read-only check. The helper requires the config to be mode `0600`. If the backup predates the managed profile home, the next activation adds it back.

## After switching profile in the app

CodexBar 0.54.1 prevents a profile switch from rendering the previous profile's token counts, costs, usage chart, top model, or cost history under the new profile. Selecting a profile doesn't guarantee an immediate local token scan. If the selected profile has no current local snapshot, use the popup's **Refresh** action. You can also close and reopen the popup after enabling **Refresh all providers when opening the menu**. Quota usage can refresh independently, so it isn't evidence that the local profile scan completed.
