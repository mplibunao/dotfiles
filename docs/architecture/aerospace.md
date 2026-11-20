# AeroSpace Cheatsheet

> Quick reference for MP's AeroSpace config. Dvorak layout, Option (alt) as primary modifier.
>
> **Key Semantics**: Bindings use Dvorak character names (mnemonic). Navigation uses vim-style hjkl (character-based).

---

## Core Navigation

| Binding | Action |
|---------|--------|
| `alt + h` | Focus left |
| `alt + j` | Focus down |
| `alt + k` | Focus up |
| `alt + l` | Focus right |

## Move Windows

| Binding | Action |
|---------|--------|
| `alt + shift + h` | Move left |
| `alt + shift + j` | Move down |
| `alt + shift + k` | Move up |
| `alt + shift + l` | Move right |

## Workspaces (Numeric)

| Binding | Action |
|---------|--------|
| `alt + 1-9` | Switch to workspace |
| `alt + shift + 1-9` | Move window to workspace |
| `alt + tab` | Toggle last workspace |
| `alt + shift + tab` | Move workspace to next monitor |

## Workspaces (Lettered)

| Binding | Workspace | Mnemonic |
|---------|-----------|----------|
| `alt + shift + b` | B | **B**rowser |
| `alt + shift + t` | T | **T**erminal |
| `alt + shift + c` | C | **C**hat |
| `alt + shift + m` | M | **M**usic |

| Binding | Action |
|---------|--------|
| `alt + ctrl + b/t/c/m` | Send window to B/T/C/M |

## Window Management

| Binding | Action |
|---------|--------|
| `alt + f` | Toggle fullscreen |
| `alt + =` | Balance window sizes |
| `alt + shift + -` | Resize smaller |
| `alt + shift + =` | Resize larger |
| `alt + \` | Toggle tiles ↔ accordion |
| `alt + ,` | Toggle accordion layout |

## Service Mode

Enter with `alt + shift + ;`, then:

| Key | Action |
|-----|--------|
| `h/j/k/l` | Join with adjacent window (vim-style) |
| `r` | Reset/flatten layout |
| `f` | Toggle floating ↔ tiling |
| `backspace` | Close all windows but current |
| `esc` | Reload config & exit |

---

## App Assignments (Startup Only)

Apps are auto-assigned to workspaces **at startup only**. New windows during a session stay on current workspace.

| App | Workspace |
|-----|-----------|
| Chrome, Arc, Firefox | B (Browser) |
| Kitty, WezTerm | T (Terminal) |
| Slack, Teams, Zoom | C (Chat) |
| Spotify, Apple Music | M (Music) |

Use workspace X for mixed layouts (no auto-assignment).

---

## Differences from Default AeroSpace

| Default | Ours | Why |
|---------|------|-----|
| `alt + h/j/k/l` nav | `alt + h/j/k/l` | Same (vim-style) |
| `alt + /` | `alt + \` | Kitty uses `alt+/` for vsplit |
| `alt + -` | `alt + shift + -` | Kitty uses `alt+-` for hsplit |
| `alt + =` resize | `alt + =` balance | Repurposed; resize moved to shift variant |
| No lettered workspaces | B/T/C/M | Mnemonic workspace access |
| `alt + f` workspace F | `alt + f` fullscreen | More useful |
| Service: `alt+shift+hjkl` | Plain `h/j/k/l` | Vim-style, avoid duplicate bindings |

---

## Auto-Floating Apps

These apps float by default (from `aerospace.nix`):

- System Settings, Finder, Disk Utility
- Activity Monitor, Console, Keychain Access
- Preview, Calculator
- Karabiner-Elements, Karabiner-EventViewer
- 1Password, Keka, Archive Utility

---

## Mission Control Note

AeroSpace emulates workspaces by moving windows off-screen, which makes Mission Control (Ctrl+↑) show tiny previews. We fix this via `system.defaults.dock.expose-group-apps = true` in `nix/hosts/m5-mbp/defaults.nix`.

---

## Useful Commands (CLI)

```bash
# List windows
aerospace list-windows --all

# List workspaces
aerospace list-workspaces --all

# Reload config
aerospace reload-config

# Check what app ID is (for float rules)
mdls -name kMDItemCFBundleIdentifier -r /Applications/App.app
```

---

## Lifecycle / Gaming Mode (launchd)

> **Important**: Stop = quit process. Do NOT use `launchctl bootout` for gaming mode.
> **Note**: Do NOT run these commands with `sudo` - that targets the wrong domain.

### Stop for Gaming
```bash
osascript -e 'tell application "AeroSpace" to quit' || true
pkill -x borders 2>/dev/null || true
```
> If you quit via UI (Cmd+Q), run `pkill -x borders` separately.

### Stop (force, if wedged)
```bash
killall -x "AeroSpace" 2>/dev/null || true
pkill -x borders 2>/dev/null || true
```

### Restart (idempotent)
```bash
pkill -x borders 2>/dev/null || true; launchctl kickstart -k gui/$(id -u)/org.nix-community.home.aerospace
```

### Status
```bash
launchctl print gui/$(id -u)/org.nix-community.home.aerospace
```

### If Kickstart Fails
Check in order:
1. System Settings → General → Login Items → "Allow in the Background" (ensure AeroSpace/Home Manager is enabled)
2. Run `darwin-rebuild switch` (preferred - restores agent properly)
3. Manual repair (verify plist exists first):
   ```bash
   ls ~/Library/LaunchAgents/*aerospace* && \
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/org.nix-community.home.aerospace.plist
   ```

### Discover Service Label
If commands fail with unknown label:
```bash
launchctl list | grep -i aerospace
ls ~/Library/LaunchAgents | grep -i aerospace
```

---

## Config Location

- **TOML source (canonical)**: `nix/home/mp/modules/aerospace/aerospace.toml`
- **Nix overlays (float rules, PATH)**: `nix/home/mp/modules/aerospace/default.nix`
- **Workspace registry**: `nix/data/workspaces.toml`
- **Generated**: `~/.config/aerospace/aerospace.toml`

## Docs

- Official guide: https://nikitabobko.github.io/AeroSpace/guide
- Local: `/Users/mp/references/window-manager/AeroSpace/docs/`
