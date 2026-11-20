# Bootstrap Runbook

7-phase guide for provisioning a fresh macOS machine with this dotfiles repo's Nix configuration.

## Phase 0: Preconditions

### System Requirements
- macOS on Apple Silicon ([Cross-platform](../../../../docs/architecture/cross-platform.md#current-scope) explains why an Intel Mac isn't supported)
- Admin access (for sudo)
- Internet connection

### Manual Steps (Cannot Be Automated)
- System Preferences prompts (accessibility, disk access, etc.)
- Apple ID sign-in (if needed)
- Security approval for developer tools

### Architecture Check
```bash
# Check if Apple Silicon
uname -m
# arm64 = Apple Silicon
# x86_64 = Intel
```

---

## Phase 1: Xcode CLT + Git + SSH

### Install Xcode Command Line Tools
```bash
xcode-select --install
```
Wait for the GUI installer to complete.

### Verify Git
```bash
git --version
```

### Generate SSH Key
```bash
ssh-keygen -t ed25519 -C "markpaololibunao@gmail.com"
```
Accept defaults or customize path.

### Add SSH Key to GitHub
```bash
# Copy public key
cat ~/.ssh/id_ed25519.pub | pbcopy
```
1. Go to https://github.com/settings/keys
2. Click "New SSH key"
3. Paste and save

### Verify GitHub Access
```bash
ssh -T git@github.com
# Should see: "Hi username! You've successfully authenticated..."
```

---

## Phase 2: Clone Repos

### Create Directory Structure
```bash
mkdir -p ~/Projects/personal/ai
```

### Clone dotfiles
```bash
cd ~/Projects/personal
git clone git@github.com:mplibunao/dotfiles.git
```

### Clone claude-toolkit (Required)
```bash
cd ~/Projects/personal/ai
git clone git@github.com:mplibunao/claude-toolkit.git
```

**Required** because `claude-toolkit/setup.sh` creates symlinks for `~/.claude`, `~/.codex`, `~/.gemini`, and `~/.vibe-log`. Run `./setup.sh` after cloning.

---

## Phase 3: Homebrew

nix-darwin's Homebrew module requires Homebrew to be installed first.

### Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Add to PATH (if prompted)
For Apple Silicon:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Verify
```bash
brew --version
```

---

## Phase 4: Install Determinate Nix

### Run Installer
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Follow prompts and enter password when asked.

### Verify Nix
Open a new terminal, then:
```bash
nix --version
```

### Verify Flakes
```bash
nix flake metadata github:NixOS/nixpkgs
# Should show metadata, not an error about experimental features
```

---

## Phase 5: Bootstrap Flake

### Navigate to Nix Config
```bash
cd ~/Projects/personal/dotfiles
```

### Check Hostname
```bash
hostname -s
# e.g., "m5-mbp"
```

If your hostname doesn't match an existing host in `hosts/`, you may need to:
1. Create a new host config, or
2. Use an existing one (e.g., `m5-mbp`)

### Stage New Host Files
A clean clone has nothing to stage. If you created a host config above, stage it:
```bash
git add hosts/<new-hostname>/
```

**IMPORTANT:** Nix flakes ignore untracked files. Stage every new file the flake reads before evaluation.

### Evaluate (Level 0 - Safe)
```bash
nix flake check --no-build
```

### Build (Level 2 - Safe)
```bash
# First build via nix run (darwin-rebuild not yet installed)
nix run nix-darwin#darwin-rebuild -- build --flake .#m5-mbp
```

### Apply (Level 4 - REQUIRES USER APPROVAL)
The switch needs interactive `sudo`. After the build passes and the user approves, give them this command to run:
```bash
sudo nix run nix-darwin#darwin-rebuild -- switch --flake .#m5-mbp
```

After first switch, `darwin-rebuild` is in PATH.

### Verify Installation
```bash
# Open new terminal
darwin-rebuild --version
fish --version
```

---

## Phase 6: Agent Takeover Tooling

Install tools needed for agent-assisted development.

### Node.js (via mise)

**mise** manages Node, not fnm (see `modules/node/default.nix` and ADR-020,
which supersedes ADR-004). tier2 installs mise and `modules/fish/default.nix` activates it, so it's
on PATH after the first `darwin-rebuild switch`.

```bash
# Verify mise is available
mise --version

# Install and set the global Node version (mise downloads it imperatively)
mise use -g node@lts
```

The Fish init in `modules/node/default.nix` installs Corepack's `pnpm`/`yarn` shims into the active
Node prefix automatically, so no manual `corepack enable` step is needed.

### Global npm/pnpm CLIs (imperative)

Some CLIs aren't packaged in nixpkgs (or were dropped when upstream removed
`nodePackages` on 2026-03-03), so pnpm installs them globally instead. These installs
are **imperative**: package state lives under `$PNPM_HOME` (`~/Library/pnpm`) and
pnpm 11 links the executables into `$PNPM_HOME/bin` (which `modules/node/default.nix` adds to PATH),
but `darwin-rebuild switch` does not reinstall them. Reinstall them here on a fresh
machine:

```bash
pnpm i -g vercel
```

| CLI      | Why not in Nix                                              |
|----------|------------------------------------------------------------|
| `vercel` | Not in nixpkgs; was `nodePackages.vercel` before that set was removed upstream |

**Release-age gate:** `modules/node/default.nix` configures `~/.config/pnpm/rc` to hold back releases
newer than 7 days for supply-chain hardening (rationale lives in `modules/node/default.nix`). To
install a brand-new release immediately, override per-invocation:

```bash
pnpm i -g vercel --config.minimum-release-age=0
```

### Neovim (LazyVim config)

This dotfiles setup assumes your Neovim config lives in a separate repo at `~/.config/nvim-lazy`
and is selected via `NVIM_APPNAME=nvim-lazy`.

```bash
# Clone config repo + set NVIM_APPNAME default in Fish
~/Projects/personal/dotfiles/.claude/skills/bootstrap/scripts/bootstrap-neovim.sh

# With headless plugin restore (recommended for automated setup)
~/Projects/personal/dotfiles/.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --sync

# Validate existing setup (no clone, no fish var write)
~/Projects/personal/dotfiles/.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --validate
```

**Lazy! Syntax:** The script uses `Lazy!` (with bang) for synchronous plugin operations. The `!` makes lazy.nvim wait for completion before proceeding.

**Note:** `nvim --headless` may write to `~/.local/share/nvim` and `~/.local/state/nvim`.

If you prefer doing it manually:
- Clone: `git clone git@github.com:mplibunao/neovim-config.git ~/.config/nvim-lazy`
- Then open: `NVIM_APPNAME=nvim-lazy nvim` and run `:Lazy restore` (or `:Lazy sync`)

### Claude Code
```bash
curl -fsSL https://claude.ai/install.sh | bash
```

This installs a standalone binary to `~/.local/bin/claude` (no Node.js required).

### Codex CLI (Optional)
```bash
npm install -g @openai/codex
```

### Verify
```bash
claude --version
# codex --version (if installed)
```

---

## Phase 7: Handover

Bootstrap is complete when:
- [x] `nix --version` works
- [x] `darwin-rebuild --version` works
- [x] `darwin-rebuild build --flake .#HOSTNAME` succeeds
- [x] `claude --version` works (or preferred agent CLI)
- [x] `~/.config/nvim-lazy` exists (LazyVim config repo)

### Next Steps

1. **Read the agent rules:** `~/Projects/personal/dotfiles/AGENTS.md` states the safety rules and links the document for each topic.
2. **Follow its command ladder** (`docs/architecture/command-ladder.md`) for ongoing configuration changes.

### Operational Commands

```bash
# Status check
nix-ops status --host m5-mbp

# Verification ladder
nix-verify --host m5-mbp --to 2

# Update flake inputs
nix-ops update-inputs --host m5-mbp --yes --build
```

---

## Troubleshooting

### "flake.nix not found"
Run flake commands from the repository root, `~/Projects/personal/dotfiles/`.

### "file not found" after adding .nix
Stage new files first:
```bash
git add path/to/new-file.nix
```

### Homebrew command not found
Add to PATH manually:
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### darwin-rebuild not found
After first switch, open a new terminal or:
```bash
source /etc/static/bashrc  # or fish equivalent
```

### Wrong architecture packages
Check that the machine is Apple Silicon (see [Architecture Check](#architecture-check)) and that `nixpkgs.hostPlatform` in the host config is `aarch64-darwin`. See [System Requirements](#system-requirements).

### Home Manager collision errors
If activation stops because a file is in the way, follow ["file is in the way"](../../../../docs/architecture/troubleshooting.md#file-is-in-the-way) in the troubleshooting doc. Home Manager already moves most conflicting files aside by itself.

Then, once the user approves, give them the switch command that failed to run again. It needs interactive `sudo`. On the first switch, that's the `nix run` command from Phase 5's Apply step. After that, it's `sudo darwin-rebuild switch --flake .#m5-mbp`.

### Neovim validation fails

| Problem | Solution |
|---------|----------|
| "lazy.nvim not found" | Config didn't load. Check `init.lua` exists and has no syntax errors |
| "No plugins configured" | Run `--sync` or manually `:Lazy restore` in Neovim |
| "Config directory not found" | Run without `--validate` to clone first |
| Plugins incomplete | `lazy-lock.json` missing. Run `:Lazy sync` in Neovim interactively |

**Tip:** For debugging, open Neovim interactively to see full error messages:
```bash
NVIM_APPNAME=nvim-lazy nvim
```

### Plugins with native binaries not working

Some plugins (like `markdown-preview.nvim`, `blink.cmp`) require native binaries that must be built after installation. If `Lazy restore` was used without the `--sync` flag's force-build step, builds may have been skipped.

**Symptoms:**
- markdown-preview shows Node.js version instead of opening browser
- Plugin loads but features don't work
- Architecture mismatch errors on Apple Silicon

**Why this happens:** lazy.nvim's build step only runs if the plugin is "dirty" (has git changes). On a fresh clone where plugins are already at the correct commit, they're not marked dirty, so builds are skipped.

**Fix (automated):**
```bash
# Re-run bootstrap with --sync (includes force-build step)
~/Projects/personal/dotfiles/.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --sync
```

**Fix (manual):**
```bash
# Force-build all plugins with build configurations
NVIM_APPNAME=nvim-lazy nvim --headless -c 'lua require("lazy").build({wait=true})' -c 'qa!'

# Or build a specific plugin
NVIM_APPNAME=nvim-lazy nvim -c 'Lazy build markdown-preview.nvim'
```

**Verification:**
```bash
# Check markdown-preview binary exists and is correct architecture
file ~/.local/share/nvim-lazy/lazy/markdown-preview.nvim/app/bin/markdown-preview-macos-arm64
# Should show: Mach-O 64-bit executable arm64
```

---

## Creating a New Host Configuration

If this machine's hostname differs from `m5-mbp`, follow [Adding a host](../../../../docs/architecture/hosts.md#adding-a-host) before Phase 5's build.
