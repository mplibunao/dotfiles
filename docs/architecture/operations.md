# Operations: Update and Rollback

Procedures for updating flake inputs, applying changes, and rolling back. Every `darwin-rebuild switch` below, including a rollback, changes the live system and needs my approval ([`AGENTS.md`](../../AGENTS.md)). The [command ladder](command-ladder.md) covers the checks before it.

---

## Quick Reference

| Operation | Command |
|-----------|---------|
| Check current state | `darwin-rebuild --list-generations` |
| Update flake inputs | `nix flake update` |
| Check, build, or apply a change | [Command ladder](command-ladder.md) |
| Rollback | `sudo darwin-rebuild switch --rollback` |
| Rollback to specific | `sudo darwin-rebuild switch --switch-generation N` |

---

## Update Workflow

### Step 1: Update Flake Inputs

Update all flake inputs (nixpkgs, home-manager, nix-darwin):

```bash
cd ~/Projects/personal/dotfiles
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

Run the [command ladder](command-ladder.md) through the build.

### Step 4: Apply

Apply only after approval, with the [level 4 command](command-ladder.md#level-4-apply).

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

3. **Build before switching** with the [command ladder](command-ladder.md)

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

Follow the [OpenCode upgrade procedure](runbooks/opencode-repoprompt.md#opencode-upgrade) in these cases:

- You intend to change the OpenCode release.
- Any lock update. Review the locked revision and `narHash`, because Git tags can move.
- A RepoPrompt CE cask upgrade, which needs the same revalidation.

[ADR-021](../decisions/021-opencode-upstream-flake-for-repoprompt-acp.md) records the source decision.

### OpenCode rollback limits

To roll back an OpenCode change, use the [rollback workflow](#rollback-workflow) above. The [OpenCode rollback procedure](runbooks/opencode-repoprompt.md#opencode-rollback) lists what a rollback leaves in place and how to verify afterward.

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

## Operational Scripts

`scripts/nix-verify` and `scripts/nix-ops` wrap these procedures. Home Manager links both into `~/.local/bin`. Pass `--host m5-mbp` to either one ([command ladder](command-ladder.md)).

| Command | What it does |
|---------|--------------|
| `nix-verify` | Runs the [command ladder](command-ladder.md) up to the build; `--to 3` adds the dry-run without `sudo` ([level 3](command-ladder.md#level-3-dry-run)) |
| `nix-ops status` | Shows diagnostics |
| `nix-ops update-inputs --yes` | Updates `flake.lock`; `--input NAME` updates one input and `--build` builds afterwards |
| `nix-ops generations` | Lists nix-darwin generations |
| `nix-ops rollback` | Prints `sudo darwin-rebuild switch --rollback`, `darwin-rebuild --list-generations`, and `sudo darwin-rebuild switch --switch-generation N`. With `--apply` it asks you to type `ROLLBACK`. It then runs only `sudo darwin-rebuild switch --rollback`, or the `nix run` form of it when `darwin-rebuild` is missing. Like any switch, it needs my approval |
| `nix-ops gc` | Prints `nix-collect-garbage -d` and `darwin-rebuild --list-generations`. With `--apply` it asks you to type `GC`. It then runs only `nix-collect-garbage -d`, without `sudo`. That deletes the current user's old profile generations, not the nix-darwin system generations ([Storage](storage.md#aggressive-gc)) |
| `nix-ops switch` | Prints the switch command without running it |

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
