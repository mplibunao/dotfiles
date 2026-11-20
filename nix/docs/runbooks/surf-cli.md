# Surf CLI setup and upgrades

## Ownership

Install the official [`surf-cli` npm package](https://www.npmjs.com/package/surf-cli), published from [nicobailon/surf-cli](https://github.com/nicobailon/surf-cli). npm owns the CLI and extension files. Chrome loads the extension, and Surf's bundled installer registers the native host that connects Chrome to the CLI.

Use npm for Surf to keep upgrades aligned with upstream installation instructions. Node comes from mise under the [Node runtime decision](../decisions/020-nodejs-via-mise.md). Nix owns the surrounding shell configuration. npm owns this global package. Nix switches and generation rollbacks don't change the installed Surf version.

The verified installation on 2026-10-05 uses CLI version **2.22.0** with mise Node **24**. Update this version record after a verified upgrade. Pinning the CLI version records the intended release. It doesn't lock every transitive dependency for a future reinstall.

| Component | Location |
| --- | --- |
| CLI executable | `~/.npm-global/bin/surf` |
| Official package | `~/.npm-global/lib/node_modules/surf-cli` |
| Chrome extension folder | `~/.npm-global/lib/node_modules/surf-cli/dist` |
| Native host launcher | `~/Library/Application Support/surf-cli/host-wrapper.sh` |
| Chrome registration | `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/surf.browser.host.json` |
| Shared agent skill | `~/Projects/personal/ai/claude-toolkit/.claude/skills/surf/SKILL.md` |

## Fresh machine setup

Complete the dotfiles bootstrap and mise Node setup first. From the home directory, check `node --version`, `npm prefix -g`, and `npm config get ignore-scripts`. The global npm prefix should be `~/.npm-global`; the current setup suppresses package install scripts, so native host registration is explicit.

Install the recorded release:

```sh
npm install -g surf-cli@2.22.0
surf --version
```

In Chrome, open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select the extension folder in the table. Copy the extension ID shown by Chrome. Replace `EXTENSION_ID` below with that ID:

```sh
surf install EXTENSION_ID --browser chrome
```

The bundled installer writes Chrome's registration and a launcher with the Node executable path. Reload the Surf extension, then run the verification steps below. If the Node executable or package location changes later, repeat registration and reload the extension.

## Upgrade or restore an earlier release

1. Record `surf --version` and read the target release's [release notes](https://github.com/nicobailon/surf-cli/releases) and installation instructions. Inspect source when a packaging change or failure needs explanation.
2. Confirm the executable with `command -v surf` and the global directory with `npm prefix -g`. The package directory should contain the official package rather than a link to a development checkout.
3. Run `npm install -g surf-cli@VERSION`, replacing `VERSION` with the chosen release. Use the same command with the previously recorded version to restore it.
4. Reload Surf at `chrome://extensions` so Chrome loads the updated files. Repeat native host registration if upstream requires it or the Node/package path changed.
5. Run the verification below. Update the verified version record and shared skill after a successful upgrade.

The package stays at the same npm location across upgrades. Chrome's displayed extension version comes from `dist/manifest.json` and can differ from `surf --version`: CLI 2.22.0 ships extension version 2.6.0. Check the loaded folder and manifest before treating different version numbers as a failed upgrade.

The npm release-age policy is seven days. If an explicitly approved upgrade needs an exception, scope it to that invocation and package:

```sh
npm install -g surf-cli@VERSION --min-release-age-exclude=surf-cli
```

This leaves the age rule in place for dependencies. Confirm `npm config get min-release-age` still returns `7` and `npm config get min-release-age-exclude` has no persistent exception after the operation.

## Verification

```sh
surf --version
surf doctor
surf --session surf-install-check session.ensure surf-install-check https://example.com --tab
surf --session surf-install-check page.text
```

Expect the selected CLI version, a passing doctor report, and the Example Domain page text. Record the tab ID returned by `session.ensure`; close only that test tab with `surf tab.close TAB_ID`. A passing doctor report checks the connection and registration; the page read checks an actual browser operation.

For a registration failure, compare Chrome's extension ID with the manifest's allowed origins and check that the launcher's Node and host paths exist. For unexpected command behavior, confirm that `surf` resolves to the official global package before investigating upstream changes.

## Shared skill and separate services

The installed package supplies `skills/surf/SKILL.md`. Review that file during upgrades and update the canonical shared skill in Claude Toolkit. Use the existing `codex-sync-skills` skill for managed copies and links; edit the canonical file rather than a generated copy.

The fork repository, its OpenAI gateway, the global CloakBrowser package, and `~/.surf` browser data have separate ownership. Surf package upgrades preserve them. TD-041 in `~/references/ai/surf-cli/docs/tech-debt-tracker.md` tracks the gateway's future retirement.
