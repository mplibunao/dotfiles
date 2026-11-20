# AeroSpace

AeroSpace is the tiling window manager ([ADR-006](../decisions/006-aerospace-instead-of-yabai.md)). Home Manager installs its configuration and runs it as a LaunchAgent.

## Configuration files

| What | File |
|---|---|
| Bindings, key mapping, gaps, layout, normalization, startup commands | [`modules/aerospace/aerospace.toml`](../../modules/aerospace/aerospace.toml), the canonical authored config ([ADR-014](../decisions/014-aerospace-toml-as-canonical-authored-config.md)) |
| Float rules, app-to-workspace rules, `PATH` and environment | [`modules/aerospace/default.nix`](../../modules/aerospace/default.nix), which also asserts that the TOML leaves those keys alone |
| Workspace names the Nix rules use | [`data/workspaces.toml`](../../data/workspaces.toml) |
| Generated result | `~/.config/aerospace/aerospace.toml` |

The `[mode.main.binding]` and `[mode.service.binding]` tables in `aerospace.toml` list every binding. Option (`alt`) is the main modifier, and `alt-shift-semicolon` enters service mode. [Keybindings](keybindings.md) explains how AeroSpace names keys under Dvorak.

## Workspaces and app placement

`data/workspaces.toml` names the workspaces that the rules in `default.nix` use; `aerospace.toml` names others directly in its bindings. `appAssignments` in `default.nix` lists app bundle IDs with their workspaces and becomes rules that move each app's windows there. Those rules run only while AeroSpace starts, so a window opened later stays on the current workspace. Workspaces `X` and `I` have no assignment rules, for mixed layouts and for scratch work on the built-in display.

The utilities in `floatApps` in `default.nix` (System Settings, Finder, 1Password, and others) always float. To add one, find its bundle ID:

```sh
mdls -name kMDItemCFBundleIdentifier -r /Applications/App.app
```

AeroSpace emulates workspaces by moving windows off screen, which makes Mission Control show tiny previews. `system.defaults.dock.expose-group-apps = true` in `hosts/m5-mbp/defaults.nix` groups them by app instead.

## Useful commands

```sh
aerospace list-windows --all
aerospace list-workspaces --all
aerospace reload-config
```

## Stopping for games and starting again

Stopping means quitting the process. Don't use `launchctl bootout` for this, and don't run these commands with `sudo`, which targets the wrong launchd domain. [ADR-017](../decisions/017-aerospace-keepalive-false-for-gaming-mode.md) explains why the LaunchAgent doesn't restart AeroSpace after a quit.

```sh
# Stop
osascript -e 'tell application "AeroSpace" to quit' || true
pkill -x borders 2>/dev/null || true

# Stop when AeroSpace doesn't respond
killall -x "AeroSpace" 2>/dev/null || true
pkill -x borders 2>/dev/null || true

# Start again (safe to repeat)
pkill -x borders 2>/dev/null || true; launchctl kickstart -k gui/$(id -u)/org.nix-community.home.aerospace

# Status
launchctl print gui/$(id -u)/org.nix-community.home.aerospace
```

Quitting from the menu with Cmd+Q leaves the JankyBorders process running, so run `pkill -x borders` afterwards.

If `kickstart` fails, check these in order:

1. System Settings → General → Login Items → Allow in the Background: AeroSpace and Home Manager are enabled.
2. Run `darwin-rebuild switch`, which loads the agent again. It needs my approval.
3. Load the agent by hand, after checking that the plist exists:

   ```sh
   ls ~/Library/LaunchAgents/*aerospace* && \
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/org.nix-community.home.aerospace.plist
   ```

If a command reports an unknown label, find the current one:

```sh
launchctl list | grep -i aerospace
ls ~/Library/LaunchAgents | grep -i aerospace
```

## If AeroSpace breaks after a switch

1. Reload the configuration with `aerospace reload-config`.
2. If that doesn't fix it, roll back the generation: `sudo darwin-rebuild switch --rollback`. A rollback is a switch, so it needs my approval. [Operations](operations.md#rollback-workflow) lists the generations to choose from.

## Layout manager

The `aerospace-layout` Fish function saves and restores which workspace each app's windows are on. It's defined in [`modules/fish/functions/a_mp/aerospace-layout.fish`](../../modules/fish/functions/a_mp/aerospace-layout.fish) and stores layouts as JSON in `~/.config/aerospace-layouts/`.

| Command | What it does |
|---|---|
| `save <name>` | Save the current arrangement; an existing layout with that name is overwritten |
| `restore <name>` | Restore a saved layout |
| `restore <name> --dry-run` | Show what a restore would move, without moving anything |
| `restore <name> --launch` | Start missing apps during the restore |
| `list` | List saved layouts |
| `show <name>` | Show a layout's details |
| `delete <name>` | Remove a layout |
| `help` | Show usage |

Layout names start with a lowercase letter and use lowercase letters, numbers, hyphens, and underscores, up to 32 characters, such as `coding` or `deep-work`.

A layout file looks like this:

```json
{
  "schema_version": 1,
  "name": "coding",
  "created_at": "2025-01-15T10:00:00Z",
  "scope": "focused-monitor",
  "focused_workspace": "1",
  "windows": [
    {
      "app_bundle_id": "net.kovidgoyal.kitty",
      "workspace": "1",
      "count": 1,
      "window_titles": ["dev session"]
    }
  ]
}
```

A restore checks that every workspace in the layout exists, then finds which apps are running and starts missing ones with `--launch`. It matches windows by exact title, then by case-insensitive substring, then takes any window of that app in a fixed order. It skips windows already on the right workspace and finally focuses the saved workspace.

It needs Fish 3.4.0 or later (for `string escape --style=regex`), `jq`, and a running AeroSpace. It works only on the focused monitor, and it saves workspace membership, not the tiling tree or splits. A save records one workspace per app, the workspace of that app's first window, so an app whose windows sit on several workspaces comes back on one. Window titles change, so matching by title is a hint rather than a guarantee.

When a restore reports that a workspace in the layout doesn't exist, add that workspace or save the layout again with the current workspaces. When it reports that an app isn't running, rerun it with `--launch`.

## References

- [AeroSpace guide](https://nikitabobko.github.io/AeroSpace/guide)
- A local copy of the AeroSpace docs at `~/references/window-manager/AeroSpace/docs/`
