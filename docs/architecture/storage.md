# Storage Management

> Managing Nix store size and preventing closure bloat.

This document explains how to monitor and control disk usage with Nix, particularly important given the 1TB disk constraint.

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

Remove all old generations, then GC:

```bash
# Delete all old generations
nix-collect-garbage -d

# Or delete generations older than N days
nix-collect-garbage --delete-older-than 30d
```

### Targeted Generation Cleanup

Keep only the last N generations:

```bash
# Remove all but last 5 generations
sudo nix-env --delete-generations +5 -p /nix/var/nix/profiles/system

# Then garbage collect
nix-collect-garbage
```

---

## Preventing Bloat

### 1. Use Package Tiers

Only import tiers you actually need:

```nix
# home/mp/darwin.nix
{
  imports = [
    ./packages/tier1.nix
    # ./packages/tier2.nix  # Comment out until needed
    # ./packages/tier3.nix  # Add later
  ];
}
```

### 2. Prefer Stable Nixpkgs

Use Darwin stable branches for better binary cache coverage:

```nix
# flake.nix
inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
```

Unstable can mean:
- More source builds (larger store, more time)
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

### scripts/gc

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Current store size:"
du -sh /nix/store

echo ""
echo "Current generations:"
darwin-rebuild --list-generations

echo ""
read -p "Delete generations older than 30 days? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
    nix-collect-garbage --delete-older-than 30d
    echo ""
    echo "Store size after GC:"
    du -sh /nix/store
fi
```

### scripts/store-size

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Nix Store Status ==="
echo ""
echo "Store size: $(du -sh /nix/store | cut -f1)"
echo "Store paths: $(ls /nix/store | wc -l)"
echo ""
echo "Current system closure:"
nix path-info -Sh /run/current-system
echo ""
echo "Generations:"
darwin-rebuild --list-generations | tail -5
```

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

Recovery:
```bash
# Check database
sqlite3 /nix/var/nix/db/db.sqlite "pragma integrity_check"

# If corrupted, try repair
mv /nix/var/nix/db/db.sqlite /nix/var/nix/db/db.sqlite-bkp
sqlite3 /nix/var/nix/db/db.sqlite-bkp ".dump" | sqlite3 /nix/var/nix/db/db.sqlite
```

### If Disk Is Full

1. Delete old generations first:
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
