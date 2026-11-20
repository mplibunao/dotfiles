# Migration Phases

> Staged migration from legacy dotfiles to Nix-based setup.

This document outlines the phased approach to migrating from a `bootstrap.sh` and symlink setup to a fully declarative Nix configuration. Each stage has explicit goals, actions, and "done" criteria.

The flake, host, Homebrew, and defaults files these stages create already exist. To set up a fresh Mac from this repository, follow the [bootstrap skill](../../.claude/skills/bootstrap/SKILL.md) instead.

---

## Overview

| Stage | Name | Location | Goal |
|-------|------|----------|------|
| 1 | Minimal bootstrap | New Mac | Clone repo, configure SSH |
| 2 | Install Determinate Nix | New Mac | Get `nix` working |
| 3 | Bootstrap flake | New Mac | nix-darwin + HM skeleton |
| 4 | Tier 1 packages | New Mac | Productive CLI baseline |
| 5 | Node decision | New Mac | fnm (chosen) vs Nix-native |
| 6 | Tier 2 packages | New Mac | Development tools |
| 7 | GUI apps policy | New Mac | Manual vs Homebrew |
| 8 | macOS defaults | New Mac | System settings via nix-darwin |
| 9 | Window management | New Mac | AeroSpace + Karabiner |

---

## Stage 1: Minimal Bootstrap (New Mac)

**Location:** New Apple Silicon Mac

**Goal:** Get to "I can clone and edit the dotfiles repo."

### Actions

1. **Install Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```

2. **Generate SSH key**
   ```bash
   ssh-keygen -t ed25519 -C "markpaololibunao@gmail.com"
   eval "$(ssh-agent -s)"
   ssh-add ~/.ssh/id_ed25519
   ```

3. **Add key to GitHub**
   ```bash
   cat ~/.ssh/id_ed25519.pub
   # Copy and add to GitHub → Settings → SSH Keys
   ```

4. **Clone dotfiles**
   ```bash
   mkdir -p ~/Projects/personal
   cd ~/Projects/personal
   git clone git@github.com:mplibunao/dotfiles.git
   ```

### Done Criteria

- [ ] `git` available via Xcode CLT
- [ ] SSH key configured and added to GitHub
- [ ] Dotfiles repo cloned to `~/Projects/personal/dotfiles`

---

## Stage 2: Install Determinate Nix (New Mac)

**Location:** New Apple Silicon Mac

**Goal:** Install Nix and verify it works.

### Actions

1. **Install Determinate Nix**

   Using the graphical installer (recommended for macOS):
   - Download from [Determinate Systems](https://install.determinate.systems)
   - Or via command line:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
     sh -s -- install --determinate
   ```

2. **Verify installation**
   ```bash
   # Open new terminal
   nix --version
   # Should show Determinate Nix version
   ```

3. **Verify flakes enabled**
   ```bash
   nix flake --help
   # Should show flake subcommands, not "experimental feature"
   ```

### Done Criteria

- [ ] `nix` command available in PATH
- [ ] `nix flake` works without extra flags
- [ ] `/nix/store` directory exists

### Notes

- Determinate Nix enables flakes by default
- nix-darwin must use `nix.enable = false` because Determinate owns Nix
- Upgrades: `sudo determinate-nixd upgrade`

---

## Stage 3: Bootstrap Flake (New Mac)

**Location:** New Apple Silicon Mac

**Goal:** Establish nix-darwin + Home Manager integration with minimal config.

### Actions

1. **Create initial flake structure**
   ```
   nix/
   ├── flake.nix
   ├── hosts/<hostname>/
   │   └── configuration.nix
   └── home/mp/
       ├── common.nix
       └── darwin.nix
   ```

2. **Write flake.nix skeleton**
   ```nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
       darwin.url = "github:nix-darwin/nix-darwin";
       darwin.inputs.nixpkgs.follows = "nixpkgs";
       home-manager.url = "github:nix-community/home-manager/release-24.11";
       home-manager.inputs.nixpkgs.follows = "nixpkgs";
     };

     outputs = inputs@{ self, nixpkgs, darwin, home-manager, ... }: {
       darwinConfigurations."<hostname>" = darwin.lib.darwinSystem {
         system = "aarch64-darwin";
         modules = [
           ./hosts/<hostname>/configuration.nix
           home-manager.darwinModules.home-manager
         ];
       };
     };
   }
   ```

3. **Write minimal host config**
   ```nix
   # hosts/<hostname>/configuration.nix
   { config, pkgs, ... }:
   {
     nixpkgs.hostPlatform = "aarch64-darwin";
     nix.enable = false;  # Determinate Nix manages this

     users.users.mp = {
       name = "mp";
       home = "/Users/mp";
     };

     home-manager.useGlobalPkgs = true;
     home-manager.useUserPackages = true;
     home-manager.users.mp = import ../../home/mp/darwin.nix;

     system.stateVersion = 4;
   }
   ```

4. **Bootstrap nix-darwin**
   ```bash
   cd ~/Projects/personal/dotfiles/nix
   git add .
   nix run nix-darwin#darwin-rebuild -- switch --flake .#<hostname>
   ```

### Done Criteria

- [ ] `flake.nix` and `flake.lock` exist
- [ ] `darwin-rebuild` command available
- [ ] `darwin-rebuild switch` succeeds with minimal config
- [ ] Home Manager activated (even if empty)

---

## Stage 4: Tier 1 Packages (New Mac)

**Location:** New Apple Silicon Mac

**Goal:** Install essential CLI tools for productivity.

### Tier 1 Packages (canonical)

| Package | Purpose |
|---------|---------|
| fish | Shell |
| starship | Prompt |
| git | VCS |
| git-delta | Git pager |
| neovim | Editor |
| fzf | Fuzzy finder |
| ripgrep | Search |
| fd | Find files |
| bat | Cat replacement |
| lsd | Ls replacement |
| zoxide | Smart cd |
| kitty | Terminal (install via Homebrew cask; config via HM) |

**Source of truth:** `nix/home/mp/packages/tier1.nix` and `nix/docs/02-packages-and-tiers.md`. The table above is a quick reference and may drift.

### Actions

1. **Confirm Tier 1 list**
   - `nix/home/mp/packages/tier1.nix` is canonical (may include additional essential tools beyond this table).

2. **Program modules (config)**
   - `nix/home/mp/modules/fish.nix`
   - `nix/home/mp/modules/git.nix`
   - `nix/home/mp/modules/starship.nix`
   - `nix/home/mp/modules/neovim.nix`
   - `nix/home/mp/modules/bat.nix`
   - `nix/home/mp/modules/kitty.nix` (config only)

3. **Kitty install path**
   - Kitty is installed via Homebrew cask (see `nix/docs/gui-apps.md` and `nix/hosts/m5-mbp/homebrew.nix`).

4. **Apply and verify**
   ```bash
   darwin-rebuild switch --flake .#<hostname>
   which fish nvim git fzf
   fish -ic 'functions -q fzf_configure_bindings; and echo fzf_configure_bindings:ok; or echo fzf_configure_bindings:missing; exit'
   ```

**Note: fzf integration (legacy vs plugin)**
- Legacy fzf integration uses upstream `share/fzf/key-bindings.fish` and defines `fzf_key_bindings`.
- The current setup uses the `patrickf1/fzf.fish` plugin, which calls `fzf_configure_bindings` and does **not** define `fzf_key_bindings`.

### Done Criteria

- [ ] All Tier 1 packages available in PATH
- [ ] Fish shell configured with starship
- [ ] fzf.fish loaded (`fzf_configure_bindings` present; `fzf_key_bindings` not expected)
- [ ] Git configured with delta
- [ ] Basic editor available

---

## Stage 5: Node Decision (New Mac)

**Goal:** Choose Node.js management strategy.

### Option A: fnm (Chosen)

> **Superseded (2026-05-29):** fnm was later replaced by mise — see
> [ADR-020](decisions/020-nodejs-via-mise.md). The record below is the
> point-in-time Phase 5 decision and is kept as history.

- fnm installed via Nix (in `nix/home/mp/modules/node.nix`)
- Auto-detects `.nvmrc` and `.node-version` files
- `--use-on-cd` for automatic version switching in interactive Fish
- fnm init in both `shellInit` (non-interactive) and `interactiveShellInit`

### LLM CLI Install Methods

| Tool | Method | Location |
|------|--------|----------|
| claude-code | curl installer | `~/.local/bin/claude` |
| codex | npm global | `~/.npm-global/bin/codex` |
| gemini-cli | Nix | tier1.nix |
| poltergeist | Homebrew | homebrew.nix |

### Option B: Nix-Native (Not Chosen)

- Node via Nix
- Per-project devShells for versions
- Global CLIs via Nix or tools shell

### Actions

1. **Document decision in `decisions/`** ✅ ([ADR-004](decisions/004-nodejs-via-fnm.md))
2. **Implement fnm in `nix/home/mp/modules/node.nix`** ✅
3. **Implement LLM tools in `nix/home/mp/modules/llm-tools.nix`** ✅
4. **Verify LLM CLIs work** (claude, codex, gemini) ✅

### Done Criteria

- [x] Decision documented (ADR-004)
- [x] Node/npm available via fnm
- [x] LLM CLIs functional

---

## Stage 6: Tier 2 Packages (New Mac)

**Goal:** Add development tools.

### Tier 2 Packages

| Package | Purpose |
|---------|---------|
| docker | Containers (manual install) |
| pnpm | Package manager |
| terraform | IaC |
| terraform-ls | LSP |
| gcloud | GCP CLI |
| postgresql | DB client |
| jq | JSON processor |
| yq | YAML processor |
| lazygit | Git TUI |
| lazydocker | Docker TUI |

### Done Criteria

- [ ] Tier 2 packages available
- [ ] Docker Desktop installed and working
- [ ] LSP servers configured for Neovim

---

## Stage 7: GUI Apps Policy (New Mac)

**Goal:** Decide how to install GUI applications.

### Options

| Policy | Description | Tradeoff |
|--------|-------------|----------|
| Manual | Document checklist, install by hand | Simplest, not reproducible |
| Homebrew | nix-darwin homebrew module for casks | Adds brew dependency |
| Nix-only | Nix packages where available | Largest closures |

### Recommendation

Start with **manual installation** for Stage 1-6, then evaluate Homebrew integration once CLI baseline is stable.

### Done Criteria

- [ ] Policy documented in `decisions/`
- [ ] Essential apps installed (Chrome, Slack, etc.)
- [ ] Optional: homebrew.nix created if using Policy 2

---

## Stage 8: macOS Defaults (New Mac)

**Goal:** Configure system settings declaratively.

### Settings to Configure

| Setting | Value |
|---------|-------|
| Dock autohide | true |
| Key repeat | 2 (fast) |
| Initial key repeat | 15 |
| Show extensions | true |
| Screenshot location | ~/Pictures/screenshots |
| Dark mode | true |

### Actions

1. **Create defaults.nix**
   ```nix
   # hosts/<hostname>/defaults.nix
   {
     system.defaults = {
       dock.autohide = true;
       NSGlobalDomain.KeyRepeat = 2;
       NSGlobalDomain.InitialKeyRepeat = 15;
       NSGlobalDomain.AppleShowAllExtensions = true;
       screencapture.location = "~/Pictures/screenshots";
     };
   }
   ```

2. **Apply and verify**
   ```bash
   darwin-rebuild switch --flake .#<hostname>
   # Check Dock, key repeat, etc.
   ```

### Done Criteria

- [ ] Dock autohides
- [ ] Key repeat is fast
- [ ] Screenshots go to correct location

---

## Stage 9: Window Management (New Mac)

**Goal:** Set up AeroSpace (replacing yabai) and Karabiner.

### AeroSpace

1. Install AeroSpace manually or via Homebrew
2. Create `modules/darwin/aerospace.nix` for config management
3. Migrate keybinds from skhd

### Karabiner

1. Install Karabiner-Elements
2. Create `modules/darwin/karabiner.nix` for config management
3. Port essential rules:
   - Caps Lock → Hyper/Escape
   - Cmd+Q double-tap

### Done Criteria

- [ ] AeroSpace running with tiling
- [ ] Keybinds working (hjkl focus, space switching)
- [ ] Karabiner rules active (Caps Lock → Hyper)

---

## Post-Migration

After completing all stages:

1. **Document remaining manual steps**
2. **Set up regular GC schedule**

See [04-operations-update-rollback.md](./04-operations-update-rollback.md) for ongoing maintenance.
