# GUI Applications

> Tracking GUI application management for the Nix-based macOS setup.

**Policy:** Homebrew casks via nix-darwin (ADR-005), with limited Homebrew brews allowed via exception (ADR-016).

**Cleanup:** `onActivation.cleanup = "uninstall"` (changed from `"zap"` per ADR-016 to protect stateful app data)

---

## Managed via nix-darwin Homebrew Casks

[`hosts/m5-mbp/homebrew.nix`](../../hosts/m5-mbp/homebrew.nix) declares every cask under `homebrew.casks`, each with a comment saying what it is. That file is the list of casks, so this document doesn't repeat it. It numbers its group comments Tier 1 to Tier 4. They only group casks by purpose and have no relation to the closure tiers in [Packages and tiers](packages-and-tiers.md).

### CodexBar (RepoPrompt profile home)

`mp.codexbar.enable` keeps RepoPrompt CE's isolated Codex home available as an alternate profile in CodexBar. The [CodexBar runbook](runbooks/codexbar.md) has the version check, the reconcile and removal commands, and recovery from backups. [ADR-022](../decisions/022-codexbar-profile-home-merge-boundary.md) records the ownership split.

### KeyCastr (post-install)

KeyCastr requires Input Monitoring permission (and if prompted, Accessibility).

**Setup:**
1. System Settings → Privacy & Security → Input Monitoring → Enable KeyCastr
2. If KeyCastr doesn't appear in the list, launch it from `/Applications/KeyCastr.app` first

**Troubleshooting:**
If keystrokes don't appear: re-check Input Monitoring/Accessibility, then quit/relaunch KeyCastr. Permissions are tied to the specific installed app (bundle id/signature), so reinstalling/moving the app can require re-enabling.

---

## Managed via nix-darwin Homebrew Brews (Exception)

The same [manifest](../../hosts/m5-mbp/homebrew.nix) declares formulae for CLI tools and runtime dependencies under `homebrew.brews`, each with a comment giving its reason. [ADR-016](../decisions/016-homebrew-formulae-for-third-party-tap-tools.md) says when to use a formula instead of a Nix package. A formula from a third-party tap needs the checks in [Supply-chain verification](#supply-chain-verification-third-party-taps).

---

## Managed via Nix Packages

These apps are installed via Nix (Home Manager or nix-darwin):

| App | Status | Notes |
|-----|--------|-------|
| TinyCast | ✅ Configured | Primary launcher via [Tier 1](../../home/mp/package-tiers/tier1.nix); [setup guide](tinycast.md) |

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
| AudioPriorityBar | No Homebrew cask or Nix package | `AudioPriorityBar.zip` from [tobi/AudioPriorityBar releases](https://github.com/tobi/AudioPriorityBar/releases), unzipped to `/Applications/AudioPriorityBar.app` |

AudioPriorityBar keeps the external microphone as the default input, so dictation and recording apps don't switch to the iPhone microphone. Its release builds are ad-hoc signed, with no Developer ID, so Gatekeeper rejects the app; on first launch, allow it with **Open Anyway** in System Settings → Privacy & Security. To update, download the latest release and replace the app.

---

## Login Items

AudioPriorityBar, TinyCast, and NordVPN start at login. macOS keeps that list, not this repository: set it in System Settings → General → Login Items, or in the app's own settings ([TinyCast](tinycast.md#installation-and-startup) has a **Launch at Login** switch).

---

## Adding a New App

1. Find the cask name: `brew search <app>`
2. **Preflight**: Verify the token exists. Nix won't catch a bad token until the switch:
   ```bash
   brew info --cask <new-cask-token>
   # For tap casks: brew info --cask steipete/tap/<cask-token>
   ```
3. Add the token to `homebrew.casks` in `hosts/m5-mbp/homebrew.nix`, under the closest group comment, with a comment on the same line saying what the app is.
4. Check the change with the [command ladder](command-ladder.md). The switch needs approval ([`AGENTS.md`](../../AGENTS.md)).

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
