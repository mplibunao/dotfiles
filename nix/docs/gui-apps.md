# GUI Applications

> Tracking GUI application management for the Nix-based macOS setup.

**Policy:** Homebrew casks via nix-darwin (ADR-005), with limited Homebrew brews allowed via exception (ADR-016).

**Cleanup:** `onActivation.cleanup = "uninstall"` (changed from `"zap"` per ADR-016 to protect stateful app data)

---

## Managed via nix-darwin Homebrew Casks

These apps are declaratively managed in `nix/hosts/m5-mbp/homebrew.nix`:

### Tier 1: Development
| App | Cask | Status |
|-----|------|--------|
| Cursor | `cursor` | ✅ Configured |
| Docker Desktop | `docker` | ✅ Configured |
| Karabiner-Elements | `karabiner-elements` | ✅ Configured |
| Kitty | `kitty` | ✅ Configured |
| Postgres.app | `postgres-unofficial` | ✅ Configured |
| VS Code | `visual-studio-code` | ✅ Configured |

### Tier 2: Productivity
| App | Cask | Status |
|-----|------|--------|
| 1Password | `1password` | ✅ Configured |
| Dropbox | `dropbox` | ✅ Configured |
| Google Chrome | `google-chrome` | ✅ Configured |
| Firefox | `firefox` | ✅ Configured |
| Slack | `slack` | ✅ Configured |
| Zoom | `zoom` | ✅ Configured |

### Tier 3: Communication
| App | Cask | Status |
|-----|------|--------|
| Telegram | `telegram` | ✅ Configured |
| Viber | `viber` | ✅ Configured |

### Tier 3: Utilities
| App | Cask | Status |
|-----|------|--------|
| CodexBar | `steipete/tap/codexbar` | ✅ Configured |
| KeyCastr | `keycastr` | ✅ Configured |
| MonitorControl | `monitorcontrol` | ✅ Configured |
| Obsidian | `obsidian` | ✅ Configured |
| Repo Prompt | `repo-prompt` | ✅ Configured |
| RepoPrompt CE | `repoprompt/repoprompt-ce/repoprompt-ce` | ✅ Configured |

#### CodexBar (RepoPrompt profile home)

CodexBar counts only the active Codex session home, and RepoPrompt CE runs its bundled Codex against an isolated one. `mp.codexbar.enable` keeps that home available as an alternate profile by reconciling a single array member of CodexBar's own writable config at activation time. It does not combine the normal and RepoPrompt homes into one total. ADR-022 records the ownership split; the commands below are the operational surface.

CodexBar 0.54.1 prevents a profile switch from rendering the previous profile's token counts, costs, usage chart, top model, or cost history under the new profile. Selecting a profile doesn't guarantee an immediate local token scan. If the selected profile has no current local snapshot, use the popup's **Refresh** action. You can also close and reopen the popup after enabling **Refresh all providers when opening the menu**. Quota usage can refresh independently, so it isn't evidence that the local profile scan completed.

The app self-updates through Sparkle, so the installed bundle can be newer than the Homebrew receipt. Compare all four versions before any Homebrew operation on this cask, because a `brew upgrade --cask` driven by stale tap metadata can replace a newer bundle:

```bash
defaults read /Applications/CodexBar.app/Contents/Info CFBundleShortVersionString
codexbar --version
brew list --versions --cask codexbar
brew info --json=v2 --cask codexbar | jq -r '.casks[0].version'
```

After any in-app or cask update, revalidate with the read-only check. It reports the same four versions and validates the schema without writing:

```bash
codexbar-config check \
    --config "$HOME/.config/codexbar/config.json" \
    --profile-home "$HOME/Library/Application Support/RepoPrompt CE/Codex/Release/home"
```

Activation defers rather than racing a running app, and prints the command to finish the job. Quit CodexBar first, then:

```bash
codexbar-config reconcile \
    --config "$HOME/.config/codexbar/config.json" \
    --profile-home "$HOME/Library/Application Support/RepoPrompt CE/Codex/Release/home" \
    --backup-dir "$HOME/.local/state/codexbar-config/backups"
```

To hand the value back to CodexBar temporarily, quit the app and swap `reconcile` for `remove-managed-profile` with the same arguments. It removes that one path and nothing else. While `mp.codexbar.enable` stays true, a later activation will reconcile the path back into CodexBar's configuration. Durable rollback requires first disabling the option or removing the module in a reviewed change before a later approved switch.

Every write first stores a byte-for-byte copy under `~/.local/state/codexbar-config/backups/`, and nothing prunes them. Those backups are the only recovery source for this file: `darwin-rebuild switch --rollback` restores the module, not the app's writable JSON.

On a machine where CodexBar has never run, there is no config to merge into and activation fails closed. Launch the app once so it writes its own skeleton, or leave `mp.codexbar.enable = false` until then. The config at `~/.config/codexbar/config.json` must exist before reconciliation. Activation doesn't copy, rename, reconcile, or delete the legacy `~/.codexbar/config.json`.

#### KeyCastr (post-install)

KeyCastr requires Input Monitoring permission (and if prompted, Accessibility).

**Setup:**
1. System Settings → Privacy & Security → Input Monitoring → Enable KeyCastr
2. If KeyCastr doesn't appear in the list, launch it from `/Applications/KeyCastr.app` first

**Troubleshooting:**
If keystrokes don't appear: re-check Input Monitoring/Accessibility, then quit/relaunch KeyCastr. Permissions are tied to the specific installed app (bundle id/signature), so reinstalling/moving the app can require re-enabling.

### Tier 4: Media/Other
| App | Cask | Status |
|-----|------|--------|
| Discord | `discord` | ✅ Configured |
| Figma | `figma` | ✅ Configured |
| NordVPN | `nordvpn` | ✅ Configured |
| Spotify | `spotify` | ✅ Configured |
| Steam | `steam` | ✅ Configured |
| VLC | `vlc` | ✅ Configured |

---

## Managed via nix-darwin Homebrew Brews (Exception)

These CLI tools and runtime dependencies are managed in `nix/hosts/m5-mbp/homebrew.nix` under `homebrew.brews` (see ADR-016):

| Tool | Formula | Status |
|------|---------|--------|
| Bitbucket CLI | `gildas/tap/bitbucket-cli` | ✅ Configured |
| Mole | `mole` | ✅ Configured |
| RTK | `rtk` | ✅ Configured |
| SQLite | `sqlite` | ✅ Configured — gno macOS sqlite-vec `libsqlite3.dylib` runtime dependency |
| SwiftLint | `swiftlint` | ✅ Configured — RepoPrompt CE lint dependency |
| Watchman | `watchman` | ✅ Configured |

---

## Managed via Nix Packages

These apps are installed via Nix (Home Manager or nix-darwin):

| App | Status | Notes |
|-----|--------|-------|
| TinyCast | ✅ Configured | Primary launcher via [Tier 1](../home/mp/packages/tier1.nix); [setup guide](tinycast.md) |

### Hunk (post-install smoke)

Run these after an approved nix-darwin switch. Hunk is provided by its flake package.

```bash
hunk --version
hunk skill path
```

---

## Not Yet Added (Evaluate)

| App | Cask Name | Notes |
|-----|-----------|-------|
| Anki | `anki` | Flashcards |

---

## Manual Install Required

These cannot be managed via Homebrew:

| App | Reason | Install Method |
|-----|--------|----------------|
| App Store apps | App Store only | Manual via App Store |
| Licensed apps | Activation required | Manual + license key |

---

## Manually Managed Apps

Apps tracked in `dotfiles/manual-apps/` - used when no Homebrew cask is available.
See ADR-015 for decision rationale.

| App | Update Mechanism | Why Not Homebrew/Nix |
|-----|-----------------|---------------------|
| AudioPriorityBar | GitHub releases | No Homebrew cask available |

### Commands

```bash
# Check for updates
./manual-apps/manual-apps.py check

# Update specific app
./manual-apps/manual-apps.py update AudioPriorityBar

# Update all
./manual-apps/manual-apps.py update-all
```

### When to Use

Use `manual-apps/` when:
- No Homebrew cask exists for the app
- The cask is unsuitable (broken, outdated, wrong variant)

Otherwise, prefer Homebrew casks in `homebrew.nix`.

See `manual-apps/README.md` for adding new apps.

---

## Adding a New App

1. Find the cask name: `brew search <app>`
2. **Preflight**: Verify token exists (Nix won't catch bad tokens until switch):
   ```bash
   brew info --cask <new-cask-token>
   # For tap casks: brew info --cask steipete/tap/<cask-token>
   ```
3. Add to `nix/hosts/m5-mbp/homebrew.nix`:
   ```nix
   casks = [
     "existing-app"
     "new-app"  # Description
   ];
   ```
4. Stage and verify:
   ```bash
   git add nix/hosts/m5-mbp/homebrew.nix
   nix flake check --no-build
   darwin-rebuild build --flake ./nix#m5-mbp
   ```
5. Apply (with user approval):
   ```bash
   sudo darwin-rebuild switch --flake ./nix#m5-mbp
   ```

**Note:** `cleanup = "uninstall"` will remove any manually-installed brews/casks not declared in homebrew.nix.

---

## Supply-Chain Verification (third-party taps)

Third-party tap casks and formulae require post-install verification. Keep the tap list small and verify each tapped formula or cask by its fully-qualified token.

### Cask (GUI) Verification

```bash
# Full signature info (review all output for audit trail)
codesign -dv --verbose=4 /Applications/<AppName>.app 2>&1

# Extract key fields for recording
codesign -dv --verbose=4 /Applications/<AppName>.app 2>&1 | grep -E 'Authority|TeamIdentifier|Identifier'

# Check Gatekeeper assessment
spctl --assess --type execute --verbose=4 /Applications/<AppName>.app
```

### Formulae (CLI) Verification

For tap-installed brews, review the formula definition and resolved metadata. This is more reliable than codesign for CLI tools and works across third-party taps.

```bash
# Primary: inspect what you're installing
brew cat gildas/tap/bitbucket-cli

# Check resolved URLs, versions, and bottles
brew info --json=v2 gildas/tap/bitbucket-cli | jq '.formulae[0] | {name, full_name, tap, versions, urls, bottle}'
```

Record tap commit at time of install or update for audit trail:

```bash
# Get tap commit (requires local tap clone)
for tap in gildas/tap repoprompt/repoprompt-ce steipete/tap; do
  tap_dir="$(brew --repo "$tap")"
  printf '%s ' "$tap"
  git -C "$tap_dir" rev-parse HEAD
  git -C "$tap_dir" log -1 --oneline
done
```

### Expected Verification Records

| Item | Type | Verification | Status |
|------|------|--------------|--------|
| CodexBar | cask | TeamIdentifier | Pending |
| RepoPrompt CE | cask | `/Applications/RepoPrompt CE.app` TeamIdentifier + Gatekeeper | Pending |
| hunk | flake package | `nix build` + `hunk --version` + `hunk skill path` | Pending |

Re-verify after tap updates.

---

## Notes

- `onActivation.cleanup = "uninstall"` removes undeclared brews and casks (preserves cask app data; see ADR-016)
- Prefer Nix packages when available and functional
- GUI apps via Homebrew are installed to `/Applications/`
- TinyCast uses a local Nix package for the signed upstream app.
