# Storage Management

How to monitor and control the Nix store's disk use on a 1 TB disk, and how to keep the closure from growing. Deleting generations removes rollback targets, so treat cleanup as its own decision.

---

## Understanding Nix Storage

### What Takes Space

| Component | Location | Description |
|-----------|----------|-------------|
| Nix store | `/nix/store` | All packages, derivations, build outputs |
| Generations | `/nix/var/nix/profiles` | Symlinks to store paths |
| GC roots | Various | Paths that prevent garbage collection |

### Why Space Accumulates

1. **Generations:** Each `darwin-rebuild switch` creates a new generation
2. **Dependencies:** Packages pull in their entire dependency tree (closure)
3. **Build artifacts:** Development builds may leave intermediates
4. **Unused packages:** Old packages remain until GC

---

## Monitoring Storage

### Check Store Size

```bash
# Total store size
du -sh /nix/store

# Store with breakdown
nix-store --query --requisites /run/current-system | wc -l
```

### Check Closure Size

See what a specific configuration pulls in:

```bash
# Current system closure size
nix path-info -Sh /run/current-system

# Before adding a package, check its closure
nix path-info -Sh nixpkgs#<package>
```

### List Generations

```bash
# Darwin generations
darwin-rebuild --list-generations

# Home Manager generations (if standalone)
home-manager generations
```

---

## Garbage Collection

### Basic GC

Remove unreachable store paths (respects GC roots like current generations):

```bash
nix-collect-garbage
```

### Aggressive GC

Delete old generations, then GC:

```bash
# Delete old generations of the current user's profiles
nix-collect-garbage -d

# Or delete generations older than N days
nix-collect-garbage --delete-older-than 30d
```

Run without `sudo`, these remove only the generations of profiles the current user owns. The nix-darwin system generations, which `darwin-rebuild --list-generations` lists and `darwin-rebuild switch --rollback` goes back to, are in the root-owned `/nix/var/nix/profiles`. [Targeted Generation Cleanup](#targeted-generation-cleanup) removes them.

### Targeted Generation Cleanup

Keep only the last N system generations, the rollback targets:

```bash
# Remove all but last 5 generations
sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system

# Then garbage collect
nix-collect-garbage
```

---

## Preventing Bloat

### 1. Use Package Tiers

Only import tiers you actually need. [`home/mp/darwin.nix`](../../home/mp/darwin.nix) imports the tier files, and commenting out a tier's import drops its packages from the closure.

### 2. Know the Cost of Unstable Nixpkgs

The flake follows `nixpkgs-unstable` ([ADR-008](../decisions/008-nixpkgs-unstable-nix-darwin-master.md)). Compared with a stable branch, that means:
- More source builds when the binary cache hasn't caught up (larger store, more time)
- Frequent changes (more generations)

### 3. Check Package Size Before Adding

Before adding a new package:

```bash
# Check closure size
nix path-info -Sh nixpkgs#<package>

# See dependencies
nix-store -q --tree $(nix-build '<nixpkgs>' -A <package> --no-out-link)
```

Large closures (>1GB) should be evaluated carefully.

### 4. Use DevShells for Project Tools

Don't install project-specific tools globally. Use devShells:

```nix
# In project's flake.nix
devShells.default = pkgs.mkShell {
  packages = [ pkgs.nodejs pkgs.yarn ];
};
```

Then activate per-project:
```bash
nix develop
```

This isolates project dependencies from your global profile.

### 5. Avoid Duplicate Ecosystems

If using Nix for CLI tools, don't also install them via:
- Homebrew
- npm -g
- pip install --user
- cargo install

Choose one source per tool category.

---

## Storage Policy

### Recommended Routine

| Frequency | Action |
|-----------|--------|
| Weekly | Check store size |
| Monthly | GC generations older than 30 days |
| After major updates | Full GC if space is tight |

### Target Metrics

| Metric | Target | Alert |
|--------|--------|-------|
| Store size | < 50GB | > 100GB |
| Generations | < 10 | > 20 |
| Available disk | > 100GB | < 50GB |

---

## Scripts

`nix-ops gc` prints `nix-collect-garbage -d` and `darwin-rebuild --list-generations` without running either. With `--apply` it asks you to type `GC` in an interactive terminal. It then runs only `nix-collect-garbage -d`, without `sudo`. That deletes the current user's old profile generations, which are the rollback targets for those profiles, and then collects garbage. It leaves the nix-darwin system generations ([Aggressive GC](#aggressive-gc)). [Operations](operations.md#operational-scripts) lists the other `nix-ops` commands.

---

## What NOT to Do

### Don't Delete Store Paths Manually

```bash
# NEVER DO THIS
rm -rf /nix/store/...
```

This corrupts the Nix database. Always use `nix-collect-garbage`.

### Don't Keep Too Many Generations

Old generations pin old store paths, preventing GC.

### Don't Install Heavy Dev Tools Globally

Large toolchains (Android SDK, full texlive, etc.) should be in project devShells, not global packages.

### Don't Mix Package Managers

Avoid:
```bash
# Same tool from multiple sources
nix profile install nixpkgs#nodejs
brew install node
npm install -g n
```

---

## Recovery

### If Store Becomes Corrupted

Symptoms:
- `error: database disk image is malformed`
- Missing store paths

Recovery. The database is owned by root, so the repair needs `sudo`:
```bash
# Check database
sqlite3 /nix/var/nix/db/db.sqlite "pragma integrity_check"

# If corrupted, try repair
sudo mv /nix/var/nix/db/db.sqlite /nix/var/nix/db/db.sqlite-bkp
sqlite3 /nix/var/nix/db/db.sqlite-bkp ".dump" | sudo sqlite3 /nix/var/nix/db/db.sqlite
```

### If Nix Reports a Store Schema Version Mismatch

Symptom: `current Nix store schema is version X, but I only support Y`. The installed Nix doesn't support the schema version the database has. The database isn't damaged, so the repair above doesn't apply. Export with the Nix that supports it, then import with the installed one:

```bash
# Export with new version
/path/to/new/nix-store --dump-db > /tmp/db.dump

# Reimport with old version
nix-store --load-db < /tmp/db.dump
```

### If Disk Is Full

1. Delete old generations first ([Aggressive GC](#aggressive-gc) says which generations each form removes):
   ```bash
   nix-collect-garbage -d
   ```

2. If still full, identify large closures:
   ```bash
   nix path-info -Sh /nix/var/nix/profiles/* | sort -hk2
   ```

3. Remove unused profiles or switch to smaller configuration

---

## Monitoring Commands

```bash
# Quick status
echo "Store: $(du -sh /nix/store | cut -f1), Paths: $(ls /nix/store | wc -l)"

# Largest store paths
du -sh /nix/store/* 2>/dev/null | sort -hr | head -20

# What's keeping a path alive
nix-store --query --roots /nix/store/<path>

# Closure of current system
nix path-info -rSh /run/current-system | sort -hk2 | tail -20
```
