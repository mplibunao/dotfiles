# TinyCast

TinyCast is the primary macOS launcher, installed through
[Tier 1](../../home/mp/package-tiers/tier1.nix). The
[package definition](../../packages/tinycast/default.nix) pins the official
Apple Silicon release and its archive checksum. Update the version and checksum
together. The package preserves the upstream code signature.

## Installation and startup

Follow the [Nix verification and activation procedure](command-ladder.md).
Home Manager installs the app at `~/Applications/Home Manager Apps/Tinycast.app`.

After activation, open that app and enable **Launch at Login** in TinyCast settings.
Remove Raycast from macOS login items and quit it. The launcher shortcut is
**Option + Space**, which works independently of letter positions on Dvorak.

## Extensions and settings

TinyCast owns its preferences and extension state under
`~/Library/Application Support/com.tinycast.app/` and
`~/Library/Preferences/com.tinycast.app.plist`. Nix manages the app package.
Rebuilding the package preserves these settings.

### Version-controlled preferences

Enable **Settings → Backup → Settings File** to synchronize supported preferences
with `~/.config/tinycast/settings.json`. Home Manager links that file to
[`settings.json`](../../modules/tinycast/settings.json) in this checkout.
TinyCast can write through the link, so changes made in the app appear in Git.
The [module](../../modules/tinycast/default.nix) follows the decision for
app-written configuration in [ADR-019](../decisions/019-store-managed-file-mappings-by-default.md).

For an existing local settings file, review it and copy the preferences to the
repo file before linking. Quit TinyCast, then run this from the dotfiles root:

```sh
go run scripts/tinycast-link-settings.go
```

The script creates the link only when the local and repo files match. It keeps
a backup beside the local file. Follow the
[Nix verification and activation procedure](command-ladder.md)
so Home Manager owns the mapping. Reopen TinyCast after linking. On a fresh
machine, activate the mapping first, then enable Settings File and choose
**Import** when prompted. This order follows the
[upstream 0.11.12 settings-file documentation](https://github.com/abue-ammar/tinycast/blob/v0.11.12/docs/features/settings-file.md).

After activation, check the link from the dotfiles root:

```sh
go run scripts/tinycast-link-settings.go --check
```

Change one preference in TinyCast and check
`git diff -- modules/tinycast/settings.json`. Restore the preference
in TinyCast, then repeat the link check. This confirms the app writes to the repo file
without replacing the link.

This file covers supported preferences, including the Notes and Snippets folder
paths. It excludes note and snippet contents, clipboard history, credentials,
and extension-specific preferences such as Coffee's menu-bar switch. These limits
follow the [upstream key schema](https://github.com/abue-ammar/tinycast/blob/v0.11.12/Tinycast/Features/Settings/Model/SettingsFileKey.swift).
Those data stay in TinyCast's local storage. Review settings diffs before
committing or building, especially custom folder paths and AI system prompts.
Tracked settings can enter the Nix store through a flake source snapshot.

The link follows the current checkout. Switching branches can change the live
preferences or leave the link without a target if the file is absent. Use Git
history to recover preference contents. A Nix rollback only restores the mapping.

Jira, Bitbucket, and GitHub use their existing API tokens. All three loaded live
results after credential recovery on 2026-09-29. Spotify and application launching
also passed testing. Keep extension credentials outside Git and the Nix store:
version 0.11.3 stores extension preferences in local JSON files.

Export selected settings through **Settings → Backup** for recovery. Exports omit
extension code, sign-ins, and the switch that enables extensions.
Store API tokens separately in a password manager. Review exports before putting
settings in Git, excluding clipboard history and personal notes.

## Compatibility

Version 0.11.3 doesn't support menu-bar extension commands, including Coffee's
menu-bar control. Coffee's sleep-prevention commands stop existing `caffeinate`
processes before starting a new one, so they can interrupt other keep-awake sessions.
