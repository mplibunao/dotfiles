# Agent Instructions

> Canonical agent guardrails for `dotfiles/nix/`.

This document defines the rules, conventions, and safety boundaries for agents working with the Nix-based dotfiles setup. Following these guidelines prevents accidental system modifications and ensures changes are verifiable before application.

---

## Keyboard Layout Note

**MP uses a Dvorak keyboard layout.** When working with keybindings:

- Window manager bindings (AeroSpace) use `key-mapping.preset = "dvorak"`
- CapsLock is a physical Karabiner binding: tap sends Escape; hold emits Hyper (Shift+Command+Control+Option).
- Validate keybind changes with `dotfiles/keybinds/` conflict detection tooling
- The keybind system currently uses string-based canonicalization (keycode normalization planned)
- See `keybinds/manifest.toml` for all tracked keybind sources

### AeroSpace Key Semantics Contract

With `key-mapping.preset = 'dvorak'` in aerospace.toml:
- Binding keys are **Dvorak characters** (mnemonic), not physical positions
- Example: `alt-b` means press the key labeled 'b' on Dvorak layout
- Navigation uses vim-style hjkl (character-based, for muscle memory consistency)

This invariant is enforced in:
- `aerospace.toml` (header comment)
- `AeroSpaceExtractor` notes

**Do not mix physical and mnemonic interpretations.**

### AeroSpace Layout Manager

Fish functions for saving/restoring workspace arrangements:

```fish
# Save current layout
aerospace-layout save coding

# Restore a saved layout
aerospace-layout restore coding

# Preview restore without changes
aerospace-layout restore coding --dry-run

# Launch missing apps during restore
aerospace-layout restore coding --launch

# List all saved layouts
aerospace-layout list
```

**Files:**
- Fish function: `nix/home/mp/modules/fish/functions/a_mp/aerospace-layout.fish`
- Layout storage: `~/.config/aerospace-layouts/*.json`

See `nix/docs/aerospace-layouts.md` for full documentation.

### AeroSpace Rollback Procedures

If AeroSpace breaks after `darwin-rebuild switch`:

1. **Try reload first:**
   ```bash
   aerospace reload-config
   ```

2. **Rollback Nix generation:**
   ```bash
   sudo darwin-rebuild switch --rollback
   ```

3. **List available generations:**
   ```bash
   sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
   ```

---

## Core Safety Rules

### Rule 1: Never Run `switch` Without Explicit User Approval

Agents **must not** execute commands that modify the live system:

```bash
# FORBIDDEN without explicit user approval
darwin-rebuild switch
sudo darwin-rebuild switch
home-manager switch
```

The only exception: the user explicitly says "apply", "switch", or "go ahead and switch".

Activation on this machine requires interactive `sudo` authentication. After verification and explicit approval, hand the user the exact switch command to run; don't claim the agent can complete the activation.

### Rule 2: Always Verify Before Proposing Apply

Follow the **edit → evaluate → build → propose** workflow:

1. **Edit** Nix files
2. **Evaluate** to catch syntax/type errors
3. **Build** to verify the configuration compiles
4. **Propose** the apply step to the user

### Rule 3: Stage New Files Before Evaluation

Nix flakes in git repositories **ignore untracked files**. When adding new files:

```bash
# REQUIRED: stage new files before nix commands
git add path/to/new-file.nix

# Then evaluate
nix flake check --no-build
```

Failure to do this causes confusing "file not found" errors.

### Rule 4: Bridge Non-Declarative Steps with Scripts/Runbooks

Any step that **cannot be expressed in Nix** must be documented with:
1. A **script** in `nix/scripts/` (for automation)
2. A **runbook** reference (for manual steps)

This prevents gaps between what Nix manages and what requires manual intervention.

**Examples of non-declarative steps:**
- Installing Xcode CLT (`xcode-select --install`)
- SSH key generation and GitHub setup
- App Store apps (not available via Homebrew)
- One-time migrations or data transfers

**Where to document:**
- Bootstrap steps → `/bootstrap` command (`.claude/skills/bootstrap/`)
- Operational steps → `nix/scripts/` + this guide
- Migration steps → `docs/01-migration-phases.md`

---

## Command Ladder

Use these commands in order, stopping at "build" unless the user approves apply:

### Level 0: Static Evaluation (Fast)

```bash
# Check flake evaluates without errors (no builds)
nix flake check --no-build --all-systems
```

**Purpose:** Catches syntax errors, missing imports, type mismatches.

### Level 1: Lint and Format

`nixfmt`, `statix`, and `deadnix` are installed via Home Manager
(`home/mp/modules/nix-ops-tools.nix`), so the commands below run unconditionally
in mp's shell. `nix-verify` still keeps `command -v` guards so the script stays
portable in non-Home-Manager environments.

```bash
# Format
nixfmt nix/**/*.nix

# Lint for antipatterns
statix check nix/

# Find dead code / unused bindings
deadnix nix/
```

**Purpose:** Catches common antipatterns and unused bindings.

### Level 2: Build (Safe, No Apply)

```bash
# Build the darwin configuration without activating
darwin-rebuild build --flake .#m5-mbp

# Or from the nix/ directory
darwin-rebuild build --flake /Users/mp/Projects/personal/dotfiles/nix#m5-mbp
```

**Purpose:** Verifies the full closure can be built. Creates a `result` symlink but does **not** modify the system.

### Level 3: Dry-Run Preview (Safe)

```bash
# Preview what would change
darwin-rebuild switch --dry-run --flake .#m5-mbp
```

**Purpose:** Shows activation script effects without applying.

### Level 4: Apply (REQUIRES USER APPROVAL)

```bash
# Actually switch to the new configuration
sudo darwin-rebuild switch --flake .#m5-mbp
```

**Purpose:** Activates the new configuration. **Only run when user explicitly approves.**

---

## Repository Conventions

### Directory Structure

```
dotfiles/nix/
├── flake.nix                    # Entry point
├── flake.lock                   # Pinned dependencies
├── hosts/<hostname>/            # Per-host configurations
│   ├── configuration.nix        # nix-darwin host module
│   └── homebrew.nix             # Homebrew casks
├── home/mp/                     # User home-manager config
│   ├── common.nix               # Cross-platform settings
│   ├── darwin.nix               # macOS-specific settings
│   ├── packages/
│   │   ├── tier1.nix            # Essential packages (Day 1)
│   │   └── tier2.nix            # Development packages (Day 2-3)
│   └── modules/                 # Program configurations
│       ├── fish.nix             # Shell config
│       ├── git.nix              # Git config
│       ├── kitty.nix            # Terminal config
│       └── ...
├── scripts/                     # Operational scripts
└── docs/                        # Documentation
```

### Fish Functions

- **Always include `--description`** on every function definition. This is mandatory — it shows up in tab completion when there are few enough matches for fish to use list layout.
- **One function per file.** Filename must match the function name (e.g., `emm-clean.fish` defines `function emm-clean`). This is required for fish autoloading.
- **Drop the file into `nix/home/mp/modules/fish/functions/`** — that's it. The dir is mapped via `mkOutOfStoreSymlink` (per ADR-019), so functions are live: add, edit, rename, or delete files and fish picks them up immediately. No `fish.nix` edit, no rebuild.
- **Already-loaded functions in a running shell** need re-source to pick up edits: `functions --erase <name>` or open a new shell.
- **Stage new files with `git add`** for commit / reproducibility. (Untracked function files *are* visible to fish through the live dir symlink, so the function will work locally without staging — but it won't survive `git stash drop` or a fresh checkout, and won't appear on other machines.)
- **Authored completions are different.** They live in `nix/home/mp/modules/fish/completions/` and stay store-managed (the dir layers in generated `mise.fish`); adding/removing authored completions still requires `darwin-rebuild switch`. Do not add `pnpm.fish` there; Corepack-owned pnpm completions are generated by `node.nix` and the rationale lives in ADR-019.
- **Update the cheat sheet** when adding/updating/removing fish functions or abbreviations. The interactive HTML reference lives at `~/.agent/diagrams/tooling-personal/fish-shell/cheatsheet.html` — keep it in sync with `fish.nix` and `fish/functions/`.
- **`clm` writes a launch log.** See [`clm` Launch Log](#clm-launch-log) below for its location and contents.

```fish
# Good
function my-func --description 'Short explanation of what it does'
    # ...
end

# Bad — missing description
function my-func
    # ...
end
```

### `clm` Launch Log

`clm` makes a best-effort append of one JSON object to `$XDG_STATE_HOME/clm/launches.jsonl`, or `~/.local/state/clm/launches.jsonl` when `XDG_STATE_HOME` is unset. When logging succeeds, each record contains `at` (UTC), `cwd`, `configs`, and `args`. A failure to create or secure the directory, construct the JSON, or append the record is silent and never prevents Claude from launching.

Use this log to reconstruct a crashed session with the same MCP server set. Reusing the same set is expected to allow Claude to reuse the cached prompt prefix; a different set invalidates it. Config names are recorded in the form that replays through `clm`, so a config outside the config directory appears as its full `.json` path rather than a bare name.

`args` is recorded verbatim and may contain prompt text or other sensitive command-line values, so the directory is kept at mode `0700` and **`clm` writes nothing unless it owns that directory**. On a shared `$XDG_STATE_HOME` where the directory belongs to another user, `chmod` cannot secure it, so logging is skipped rather than publishing arguments somewhere readable. An empty log under a shared state directory is that check working.

### Where to Add Packages

1. **Determine the tier** based on urgency:
   - Tier 1: Essential for productivity (git, nvim, fish, fzf, etc.)
   - Tier 2: Development tools (terraform, gcloud, pnpm, etc.)
   - Evaluate: Not sure if needed

2. **Edit the appropriate tier file:**
   ```bash
   nvim nix/home/mp/packages/tier1.nix
   ```

3. **Add to the packages list:**
   ```nix
   { pkgs, ... }:
   {
     home.packages = with pkgs; [
       jq  # JSON processor
     ];
   }
   ```

### Where to Add Dotfiles

**Prefer Home Manager program modules** when available:

```nix
# Good: uses HM module
programs.git = {
  enable = true;
  userName = "MP";
  delta.enable = true;
};
```

**Use file mappings** for configs without HM modules:

```nix
# For ~/.config/kitty/kitty.conf
xdg.configFile."kitty/kitty.conf".source = ./kitty.conf;

# Or inline
xdg.configFile."kitty/kitty.conf".text = ''
  font_family Fira Code
  font_size 12
'';

# For arbitrary home files
home.file.".somerc".source = ./somerc;
```

**Mutable vs store-managed mappings (ADR-019):** default to store-managed sources. Use `config.lib.file.mkOutOfStoreSymlink` only for executable/iterated scripts, app-rewritten configs, or shell helpers where edit→effect feedback matters more than rebuild-time immutability. Document the qualifying condition in a module comment. See [docs/decisions/019-store-managed-file-mappings-by-default.md](docs/decisions/019-store-managed-file-mappings-by-default.md) for the full criteria and decision matrix.

### How to Add a New Host

1. **Create the host directory:**
   ```bash
   mkdir -p nix/hosts/<new-hostname>
   ```

2. **Create configuration.nix:**
   ```nix
   { config, pkgs, ... }:
   {
     nixpkgs.hostPlatform = "aarch64-darwin";  # or x86_64-darwin
     nix.enable = false;  # Determinate Nix manages this

     users.users.mp = {
       name = "mp";
       home = "/Users/mp";
     };

     home-manager.useGlobalPkgs = true;
     home-manager.useUserPackages = true;
     home-manager.users.mp = import ../../home/mp/darwin.nix;
   }
   ```

3. **Add to flake.nix:**
   ```nix
   darwinConfigurations."<new-hostname>" = darwin.lib.darwinSystem {
     system = "aarch64-darwin";
     modules = [
       ./hosts/<new-hostname>/configuration.nix
       home-manager.darwinModules.home-manager
     ];
   };
   ```

4. **Stage and verify:**
   ```bash
   git add nix/hosts/<new-hostname>/
   nix flake check --no-build
   ```

---

## Known Pitfalls

### 1. Flake Ignores Untracked Files

**Problem:** Nix flakes use git to determine file scope. Untracked files are invisible.

**Symptom:** "error: getting status of '/nix/store/.../file.nix': No such file or directory"

**Solution:**
```bash
git add path/to/new-file.nix
```

### 2. Home Manager Collision Errors

**Problem:** HM refuses to overwrite existing files not managed by HM.

**Symptom:**
```
Existing file '/home/mp/.config/git/config' is in the way
Please move the above files and try again
```

**Solution:** Move the conflicting file, then switch:
```bash
mv ~/.config/git/config ~/.config/git/config.backup
darwin-rebuild switch --flake .#m5-mbp
```

### 3. Wrong Platform in hostPlatform

**Problem:** Building on Apple Silicon with `x86_64-darwin` set.

**Solution:** Verify `nixpkgs.hostPlatform` matches the machine:
- Apple Silicon: `aarch64-darwin`
- Intel Mac: `x86_64-darwin`

### 4. nix.enable Must Be False

**Problem:** Determinate Nix manages the Nix installation. nix-darwin's `nix.*` options conflict.

**Solution:** Always include in host configuration.nix:
```nix
nix.enable = false;
```

### 5. Session Variables Not Set

**Problem:** Fish/Bash doesn't pick up HM's session variables.

**Solution:** If not using `programs.fish.enable`, source the session vars manually:
```fish
source "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
```

---

## Operational Commands

Once `nix/scripts/` is set up:

| Command | Purpose |
|---------|---------|
| `nix-verify` | Run verification ladder (safe) |
| `nix-ops status` | Show system diagnostics |
| `nix-ops update-inputs --yes` | Update flake.lock |
| `nix-ops generations` | List generations |
| `nix-ops rollback` | Print rollback commands |

---

## Quick Reference

| Action | Command | Safe? |
|--------|---------|-------|
| Evaluate | `nix flake check --no-build` | Yes |
| Format | `nixfmt nix/**/*.nix` | Yes |
| Lint | `statix check nix/` | Yes |
| Dead code | `deadnix nix/` | Yes |
| Build | `darwin-rebuild build --flake .#m5-mbp` | Yes |
| Dry-run | `darwin-rebuild switch --dry-run --flake .#m5-mbp` | Yes |
| Apply | `sudo darwin-rebuild switch --flake .#m5-mbp` | **NO - User approval required** |

---

## Checklist Before Proposing Apply

- [ ] All new files staged with `git add`
- [ ] `nix flake check --no-build` passes
- [ ] `darwin-rebuild build` succeeds
- [ ] No collision warnings in build output
- [ ] Changes documented in commit message
- [ ] User has approved the apply step

---

## Links

- [README.md](README.md) - Quick-start for humans
- [docs/00-architecture.md](docs/00-architecture.md) - System design
- [docs/01-migration-phases.md](docs/01-migration-phases.md) - Stage definitions
- [docs/04-operations-update-rollback.md](docs/04-operations-update-rollback.md) - Ops workflows
- [docs/decisions/](docs/decisions/README.md) - ADRs (per-file; `docs/09-decisions-log.md` is now a stub pointing here)
- [~/.agent/diagrams/tooling-personal/fish-shell/cheatsheet.html](file:///Users/mp/.agent/diagrams/tooling-personal/fish-shell/cheatsheet.html) - Interactive fish config cheat sheet (abbreviations, functions, plugins, features)
