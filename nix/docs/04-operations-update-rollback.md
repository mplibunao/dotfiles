# Operations: Update and Rollback

> Procedures for updating dependencies, applying changes, and rolling back.

This document covers the day-to-day operations of maintaining the Nix configuration.

---

## Quick Reference

| Operation | Command |
|-----------|---------|
| Check current state | `darwin-rebuild --list-generations` |
| Update flake inputs | `nix flake update` |
| Build without apply | `darwin-rebuild build --flake .#<hostname>` |
| Apply changes | `sudo darwin-rebuild switch --flake .#<hostname>` |
| Rollback | `sudo darwin-rebuild switch --rollback` |
| Rollback to specific | `sudo darwin-rebuild switch --switch-generation N` |

---

## Update Workflow

### Step 1: Update Flake Inputs

Update all flake inputs (nixpkgs, home-manager, nix-darwin):

```bash
cd ~/Projects/personal/dotfiles/nix
nix flake update
```

This modifies `flake.lock` with new revisions.

### Step 2: Review Changes

Check what changed:

```bash
git diff flake.lock
```

Key things to look for:
- nixpkgs revision change (major updates)
- home-manager version change
- nix-darwin version change

### Step 3: Build and Test

Build the new configuration without applying:

```bash
darwin-rebuild build --flake .#<hostname>
```

If build succeeds, the new configuration is in `./result`.

### Step 4: Apply

Apply the new configuration:

```bash
sudo darwin-rebuild switch --flake .#<hostname>
```

### Step 5: Commit

Commit the lock file update:

```bash
git add flake.lock
git commit -m "chore: update flake inputs"
```

---

## Rollback Workflow

### Immediate Rollback (Previous Generation)

If something breaks after a switch:

```bash
# Roll back to the previous generation
sudo darwin-rebuild switch --rollback
```

This restores the previous system configuration and Home Manager state.

### Rollback to Specific Generation

List available generations:

```bash
darwin-rebuild --list-generations
```

Output:
```
  42   2024-01-03 10:29
  43   2024-01-04 11:56 (current)
```

Switch to a specific generation:

```bash
sudo darwin-rebuild switch --switch-generation 42
```

### Home Manager Generations

Home Manager also tracks generations (though when using the nix-darwin module, they're linked to system generations).

View generations:
```bash
home-manager generations
```

---

## State Version Rules

### Never Change home.stateVersion

The `home.stateVersion` in your configuration should be set to the Home Manager version you **first installed** and never changed:

```nix
{
  home.stateVersion = "24.11";  # Don't change this!
}
```

**Why?** `stateVersion` tells Home Manager which migration behaviors to apply. Changing it can break existing state.

### System stateVersion

Similarly, nix-darwin has a `system.stateVersion`:

```nix
{
  system.stateVersion = 4;  # Don't change without reading release notes
}
```

---

## Update Frequency

### Recommended Schedule

| Input | Frequency | Reason |
|-------|-----------|--------|
| nixpkgs | Monthly | Security updates, new packages |
| home-manager | With nixpkgs | Keep in sync |
| nix-darwin | With nixpkgs | Keep in sync |

### Before Major Updates

1. **Check release notes**
   - [NixOS/nixpkgs releases](https://github.com/NixOS/nixpkgs/releases)
   - [Home Manager release notes](https://nix-community.github.io/home-manager/)
   - [nix-darwin releases](https://github.com/nix-darwin/nix-darwin/releases)

2. **Update one input at a time** (for debugging)
   ```bash
   nix flake lock --update-input nixpkgs
   ```

3. **Build before switching**
   ```bash
   darwin-rebuild build --flake .#<hostname>
   ```

---

## Partial Updates

### Surf CLI updates

Surf uses the official global npm package. Follow [Surf CLI setup and upgrades](runbooks/surf-cli.md) for installation, Chrome extension reloads, and verification. npm and Surf manage the package version and browser registration outside Nix generations.

### Update Single Input

Update only nixpkgs:
```bash
nix flake lock --update-input nixpkgs
```

Update only home-manager:
```bash
nix flake lock --update-input home-manager
```

### Pin to Specific Revision

If you need to pin nixpkgs to a specific commit:

```nix
# In flake.nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/abc123...";
```

Then update the lock:
```bash
nix flake update
```

### OpenCode tag updates

OpenCode's upstream flake URL names a specific version tag for RepoPrompt ACP compatibility. The configured tag does not select a later release until edited, but Git tags can move, so every lock update still requires review of the revision and `narHash`. An intentional OpenCode release change must edit the tag and update only the `opencode` input; activation remains approval-gated. After either an OpenCode tag change or a RepoPrompt CE cask upgrade, revalidate both RepoPrompt UI discovery and direct MCP execution, treating new failures as a version-pairing issue first.

Follow the canonical [OpenCode upgrade procedure](runbooks/opencode-repoprompt.md#opencode-upgrade). The source and rollback decision remains recorded in [ADR-021](decisions/021-opencode-upstream-flake-for-repoprompt-acp.md).

### OpenCode rollback limits

A Darwin generation rollback can restore the earlier OpenCode executable and `~/.local/bin/opencode` link. It does **not** roll back or delete:

- `${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json` or other OpenCode session/history/database data;
- `~/.config/opencode` or project OpenCode configuration;
- provider API keys, OAuth grants, billing, quotas, or subscriptions;
- RepoPrompt connection flags, role selections, or cached model catalogs.

Activation and rollback remain approval-gated. Credential logout, upstream key/OAuth revocation, and RepoPrompt Sign Out remain separate from generation rollback. Follow the canonical [OpenCode rollback procedure](runbooks/opencode-repoprompt.md#opencode-rollback) for post-rollback verification and recovery.

---

## Debugging Failed Updates

### Common Issues

#### 1. Package Removed or Renamed

```
error: attribute 'oldpackage' missing
```

**Solution:** Check if package was renamed or removed in new nixpkgs. Search for replacement:
```bash
nix search nixpkgs#<package>
```

#### 2. Option Removed or Changed

```
error: The option 'programs.foo.bar' does not exist
```

**Solution:** Check home-manager release notes for option changes.

#### 3. Build Failure

```
error: builder for '/nix/store/...' failed
```

**Solution:**
- Check build logs: `nix log /nix/store/...`
- Try with previous nixpkgs revision
- Report upstream if it's a packaging issue

### Recovery Steps

1. **Don't panic** - your previous generation still works
2. **Roll back** if you've already switched:
   ```bash
   sudo darwin-rebuild switch --rollback
   ```
3. **Revert flake.lock**:
   ```bash
   git checkout flake.lock
   ```
4. **Investigate** the issue before trying again

---

## Scripts

Create helper scripts in `nix/scripts/`:

### scripts/update

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Updating flake inputs..."
nix flake update

echo "Building configuration..."
darwin-rebuild build --flake .#"$(hostname -s)"

echo ""
echo "Build successful! Review changes with:"
echo "  git diff flake.lock"
echo ""
echo "Apply with:"
echo "  sudo darwin-rebuild switch --flake .#$(hostname -s)"
```

### scripts/switch

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Applying configuration..."
sudo darwin-rebuild switch --flake .#"$(hostname -s)"

echo ""
echo "Switch complete. Current generation:"
darwin-rebuild --list-generations | tail -1
```

### scripts/rollback

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Available generations:"
darwin-rebuild --list-generations

echo ""
read -p "Roll back to previous generation? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    sudo darwin-rebuild switch --rollback
    echo "Rollback complete."
fi
```

---

## Best Practices

### Before Any Update

1. Ensure clean git state
2. Commit current changes
3. Note current generation number

### After Successful Update

1. Commit flake.lock
2. Test critical workflows
3. Run garbage collection if needed

### When Something Breaks

1. Roll back immediately
2. Document the issue
3. Investigate before retrying
4. Consider partial updates to isolate the problem
