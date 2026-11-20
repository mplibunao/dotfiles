# Troubleshooting

Common issues and how to resolve them. A fix that ends in `darwin-rebuild switch` still needs my approval, as [`AGENTS.md`](../../AGENTS.md) says.

---

## Quick Diagnosis Flowchart

```
Problem occurred
       │
       ▼
┌──────────────────┐     ┌──────────────────┐
│ After rebuild?   │ Yes │ Roll back first  │
│                  │────▶│                  │
└────────┬─────────┘     └──────────────────┘
         │ No
         ▼
┌──────────────────┐     ┌──────────────────┐
│ Nix command      │ Yes │ Check PATH,      │
│ not found?       │────▶│ shell init       │
└────────┬─────────┘     └──────────────────┘
         │ No
         ▼
┌──────────────────┐     ┌──────────────────┐
│ Evaluation       │ Yes │ Check syntax,    │
│ error?           │────▶│ imports, types   │
└────────┬─────────┘     └──────────────────┘
         │ No
         ▼
┌──────────────────┐     ┌──────────────────┐
│ Build error?     │ Yes │ Check package    │
│                  │────▶│ availability     │
└────────┬─────────┘     └──────────────────┘
         │ No
         ▼
┌──────────────────┐     ┌──────────────────┐
│ Activation       │ Yes │ Check collisions │
│ error?           │────▶│ or permissions   │
└──────────────────┘     └──────────────────┘
```

---

## Evaluation Errors

### "undefined variable"

**Error:**
```
error: undefined variable 'pkgs'
```

**Cause:** Function argument missing or misspelled.

**Solution:**
```nix
# Wrong
{ config, ... }:
{
  home.packages = [ pkgs.git ];  # pkgs not in scope
}

# Right
{ config, pkgs, ... }:
{
  home.packages = [ pkgs.git ];
}
```

### "attribute missing"

**Error:**
```
error: attribute 'nonexistent' missing
```

**Cause:** Package doesn't exist in nixpkgs or typo in name.

**Solution:**
```bash
# Search for correct package name
nix search nixpkgs#<partial-name>
```

### "infinite recursion"

**Error:**
```
error: infinite recursion encountered
```

**Cause:** Circular dependency in configuration.

**Solution:** Check for self-referential definitions or `rec` patterns. Avoid `rec { }` in favor of `let ... in`.

### "option does not exist"

**Error:**
```
error: The option 'programs.foo.bar' does not exist
```

**Cause:** Option removed, renamed, or in wrong module.

**Solution:**
1. Check if option exists in your Home Manager version
2. Search options: `man home-configuration.nix | grep -i foo`
3. Check release notes for changes

---

## Build Errors

### "hash mismatch"

**Error:**
```
error: hash mismatch in fixed-output derivation
```

**Cause:** Source content changed since lock file was created.

**Solution:**
```bash
# Update the lock file
nix flake update
```

### "builder failed"

**Error:**
```
error: builder for '/nix/store/...' failed with exit code 1
```

**Solution:**
```bash
# View full build log
nix log /nix/store/<derivation-path>
```

Common causes:
- Missing build dependencies
- Incompatible versions
- Platform-specific issues

### "not available for aarch64-darwin"

**Error:**
```
error: Package 'foo' is not available on the requested hostPlatform
```

**Cause:** Package only supports Linux or Intel Mac, or the host's `nixpkgs.hostPlatform` doesn't match the machine ([Hosts](hosts.md#adding-a-host)).

**Solution:**
- Find alternative package
- Check if there's a Darwin-compatible version
- Remove package from Darwin config

---

## Activation Errors

### "file is in the way"

`hosts/m5-mbp/configuration.nix` sets `home-manager.backupFileExtension = "backup"`. When a regular file sits where Home Manager wants to put its own, activation moves it to `<file>.backup` and prints a warning:

```
Existing file '/Users/mp/.config/git/config' is in the way of '/nix/store/...', will be moved to '/Users/mp/.config/git/config.backup'
```

For an ordinary mapping, activation stops only in two cases:

- **The backup name is taken.** `Existing file '<file>.backup' would be clobbered by backing up '<file>'` means an earlier activation already left a backup there. Compare it with the current file, keep anything from it you still need, then move it to a name nothing uses:

  ```bash
  mv -n ~/.config/git/config.backup ~/.config/git/config.backup-$(date +%Y%m%d-%H%M%S)
  ```

- **The file is a symlink Home Manager doesn't own.** `Existing file '<file>' would be clobbered` means Home Manager won't move a link. Check where it points with `readlink`, then move the link aside the same way, under a name that doesn't exist yet.

Then run the switch again. Once it succeeds, compare Home Manager's file with the backup, carry any missing settings into the module, and delete the backup. Don't set `force = true` on the mapping to get past a collision.

Two kinds of mapping skip this procedure:

- Mappings with `force = true` skip the collision check, and activation replaces whatever is at the path without a backup. They are `~/.config/fish/functions`, which activation removes as a whole folder, `~/.config/karabiner`, `~/.cloudflared/config.yml`, and the `~/.local/bin` links in the last two rows of the [out-of-store table](dotfiles-mapping.md#files-linked-out-of-the-store). Move anything you want to keep at those paths aside before the switch.
- `modules/whisper-model/default.nix` checks the Whisper model's cache path before Home Manager's collision check and refuses an occupied path or an unexpected symlink. Moving or removing that path needs its own approval; the module's error message says which path.

### "permission denied"

**Error:**
```
error: cannot create symlink '...': Permission denied
```

**Cause:** File or directory has wrong permissions.

**Solution:**
```bash
# Check ownership
ls -la ~/.config/

# Fix ownership if needed
sudo chown -R $USER:staff ~/.config/
```

---

## Shell/PATH Issues

### "nix: command not found"

**Cause:** Nix not initialized in shell.

**Solution:**
```bash
# For Fish
if test -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
    source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish'
end

# For Bash/Zsh
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
```

### "darwin-rebuild: command not found"

**Cause:** nix-darwin not installed or not in PATH.

**Solution:** Use the `nix run` fallback under [If darwin-rebuild Broken](#if-darwin-rebuild-broken).

### Environment variables not set

**Cause:** Home Manager session vars not sourced. `programs.fish` sources them for Fish, so this affects other shells.

**Solution:** Add to shell config:
```bash
# If useUserPackages = true
source "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"

# If useUserPackages = false
source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
```

---

## Flake Issues

### "path not found" for new files

**Error:**
```
error: getting status of '/nix/store/.../newfile.nix': No such file or directory
```

**Cause:** File not tracked by git (flakes ignore untracked files).

**Solution:**
```bash
git add path/to/newfile.nix
nix flake check
```

### "flake.lock out of date"

**Error:**
```
warning: updating lock file 'flake.lock'
```

**Solution:** This is usually fine. Commit the updated lock file:
```bash
git add flake.lock
git commit -m "chore: update flake.lock"
```

### "input not found"

**Error:**
```
error: cannot find flake 'github:...'
```

**Cause:** Network issue or invalid flake reference.

**Solution:**
- Check internet connection
- Verify the repository/branch exists
- Try `nix flake update`

---

## macOS-Specific Issues

### After macOS Update

macOS updates can overwrite shell config.

**Symptom:** Nix not in PATH after reboot.

**Solution:** Re-add to `/etc/zshrc`:
```bash
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
```

### Gatekeeper Blocking

**Symptom:** "cannot be opened because the developer cannot be verified"

**Solution:**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine /path/to/binary
```

### Determinate Nix Issues

**Upgrade:**
```bash
sudo determinate-nixd upgrade
```

**Status:**
```bash
sudo determinate-nixd status
```

---

## Database Issues

### "database disk image is malformed"

**Cause:** Nix database corruption.

**Solution:** Check the database and repair it as [Storage](storage.md#if-store-becomes-corrupted) describes.

### "current Nix store schema is version X, but I only support Y"

**Cause:** Nix version mismatch.

**Solution:** Follow [the schema version procedure](storage.md#if-nix-reports-a-store-schema-version-mismatch) in Storage. The database isn't damaged, so the malformed-database repair doesn't apply.

---

## Cache Issues

### Slow Downloads

**Cause:** Binary cache not responding.

**Solution:**
```bash
# Skip cache temporarily
nix build --option substitute false .#<package>
```

### "querying path in database" slow

**Cause:** Negative cache hit.

**Solution:**
```bash
# Clear negative cache
nix build --option narinfo-cache-negative-ttl 0 .#<package>
```

---

## Recovery Procedures

### Complete Rollback

```bash
# 1. Roll back darwin
sudo darwin-rebuild switch --rollback

# 2. Verify working
which nix darwin-rebuild
```

### If darwin-rebuild Broken

This also covers a missing `darwin-rebuild`. Run the switch through `nix run`, which takes `darwin-rebuild` from the nix-darwin flake instead of the installed copy:

```bash
sudo nix run nix-darwin#darwin-rebuild -- switch --flake .#m5-mbp
```

This is a switch, so it needs my approval ([`AGENTS.md`](../../AGENTS.md)), and I run it myself because it needs an interactive `sudo` prompt. On a Mac that has never had nix-darwin, [Phase 5 of the bootstrap runbook](../../.claude/skills/bootstrap/references/bootstrap-runbook.md#phase-5-bootstrap-flake) builds first with `nix run`, then gives the first switch.

### If Nix Broken

Reinstall Determinate Nix:
```bash
# Uninstall
/nix/nix-installer uninstall

# Reinstall
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
  sh -s -- install --determinate
```

---

## Real Issues Encountered

These are actual issues hit during this migration, for reference.

### Fish Abbreviations Not Loading

**Symptom:** Only ~16 abbreviations available instead of 80+.

**Root Cause:** Partial migration - only a subset of abbreviations were ported from `setup-abbreviations.fish` to `shellAbbrs` in `modules/fish/default.nix`.

**Solution:** Port remaining abbreviations to `programs.fish.shellAbbrs` in `modules/fish/default.nix`.

**Lesson:** When migrating shell config, verify all abbreviations/aliases are ported, not just a sample.

### Auto-ls on cd Missing

**Symptom:** Changing directories no longer lists contents automatically.

**Root Cause:** `conf.d/30-auto-ls.fish` was not ported to Nix. The `__auto_ls` function and `--on-variable PWD` hook were missing.

**Solution:** Add to `interactiveShellInit` in `modules/fish/default.nix`:
```nix
interactiveShellInit = '''
  function __auto_ls --on-variable PWD
    if status is-interactive
      ls
    end
  end
''';
```

**Lesson:** Check all `conf.d/*.fish` files are ported, not just `config.fish`.

### interactiveShellInit Collision

**Symptom:** Only one module's shell init runs; others silently ignored.

**Root Cause:** Multiple modules (`modules/fish/default.nix` and `modules/node/default.nix`) set `programs.fish.interactiveShellInit` without ordering. Last writer wins.

**Solution:** Use `lib.mkAfter` in non-primary modules:
```nix
# In modules/node/default.nix
programs.fish.interactiveShellInit = lib.mkAfter '''
  # pnpm completion helpers - run after the modules/fish init (mise activate)
  function __mp_refresh_pnpm_completion; ...; end
''';
```

**Lesson:** When multiple modules touch the same option, use `lib.mkBefore`/`lib.mkAfter` for ordering.

### Kitty Font Not Found

**Symptom:** `[0.081] The font FiraCode Nerd Font was not found, falling back to Menlo`

**Root Cause:** Font family name mismatch. Kitty needs exact name `FiraCode Nerd Font Mono`, not `FiraCode Nerd Font`.

**Diagnosis:**
```bash
# macOS sees the font
system_profiler SPFontsDataType | grep -i fira

# Kitty lists available fonts (run inside Kitty)
kitty +list-fonts | grep -i fira
```

**Solution:** Use exact font name in `modules/kitty/default.nix`:
```nix
font = {
  name = "FiraCode Nerd Font Mono";  # Not "FiraCode Nerd Font"
  size = 12.0;
};
```

**Lesson:** Nerd Fonts have multiple variants (Mono, Propo, regular). Check `kitty +list-fonts` for exact name.

---

## Getting Help

### Useful Commands

```bash
# Show detailed error
nix build --show-trace .#<package>

# Check flake structure
nix flake show

# Evaluate specific attribute
nix eval .#darwinConfigurations.<hostname>.config.system.stateVersion
```

### Resources

- [nix.dev Troubleshooting](https://nix.dev/guides/troubleshooting)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [nix-darwin Manual](https://nix-darwin.github.io/nix-darwin/manual/)
- [NixOS Discourse](https://discourse.nixos.org/)
