# Bootstrap Runbook

7-phase guide for provisioning a fresh macOS machine with this dotfiles repo's Nix configuration.

## Phase 0: Preconditions

### System Requirements
- macOS (Apple Silicon preferred, Intel supported)
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
cd ~/Projects/personal/dotfiles/nix
```

### Check Hostname
```bash
hostname -s
# e.g., "m5-mbp"
```

If your hostname doesn't match an existing host in `hosts/`, you may need to:
1. Create a new host config, or
2. Use an existing one (e.g., `m5-mbp`)

### Stage Any New Files
```bash
git add .
```

**IMPORTANT:** Nix flakes ignore untracked files. Always stage before evaluation.

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
```bash
# Only run this with explicit user approval
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

**mise** manages Node, not fnm (see `nix/home/mp/modules/node.nix` and ADR-020,
which supersedes ADR-004). tier2 installs mise and `fish.nix` activates it, so it's
on PATH after the first `darwin-rebuild switch`.

```bash
# Verify mise is available
mise --version

# Install and set the global Node version (mise downloads it imperatively)
mise use -g node@lts
```

The Fish init in `node.nix` installs Corepack's `pnpm`/`yarn` shims into the active
Node prefix automatically, so no manual `corepack enable` step is needed.

### Global npm/pnpm CLIs (imperative)

Some CLIs aren't packaged in nixpkgs (or were dropped when upstream removed
`nodePackages` on 2026-03-03), so pnpm installs them globally instead. These installs
are **imperative**: package state lives under `$PNPM_HOME` (`~/Library/pnpm`) and
pnpm 11 links the executables into `$PNPM_HOME/bin` (which `node.nix` adds to PATH),
but `darwin-rebuild switch` does not reinstall them. Reinstall them here on a fresh
machine:

```bash
pnpm i -g vercel
```

| CLI      | Why not in Nix                                              |
|----------|------------------------------------------------------------|
| `vercel` | Not in nixpkgs; was `nodePackages.vercel` before that set was removed upstream |

**Release-age gate:** `node.nix` configures `~/.config/pnpm/rc` to hold back releases
newer than 7 days for supply-chain hardening (rationale lives in `node.nix`). To
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

1. **Read the quick-start:** `~/Projects/personal/dotfiles/nix/README.md`
2. **Understand agent rules:** `~/Projects/personal/dotfiles/nix/AGENTS.md`
3. **Use nix skill** for ongoing configuration changes

### Operational Commands

```bash
# Status check
nix-ops status

# Verification ladder
nix-verify --to 2

# Update flake inputs
nix-ops update-inputs --yes --build
```

---

## Troubleshooting

### "flake.nix not found"
Ensure you're in `~/Projects/personal/dotfiles/nix/`, not `dotfiles/`.

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
Check `nixpkgs.hostPlatform` in host config matches your machine:
- Apple Silicon: `aarch64-darwin`
- Intel: `x86_64-darwin`

### Home Manager collision errors
If HM refuses to overwrite existing files, move the file aside, then switch again with the user's approval:
```bash
mv ~/.config/conflicting-file ~/.config/conflicting-file.backup
# Only run this with explicit user approval
sudo darwin-rebuild switch --flake .#m5-mbp
```

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

If this machine's hostname differs from `m5-mbp`:

1. **Create host directory:**
   ```bash
   mkdir -p nix/hosts/<new-hostname>
   ```

2. **Copy and modify configuration:**
   ```bash
   cp nix/hosts/m5-mbp/configuration.nix nix/hosts/<new-hostname>/
   cp nix/hosts/m5-mbp/homebrew.nix nix/hosts/<new-hostname>/
   cp nix/hosts/m5-mbp/defaults.nix nix/hosts/<new-hostname>/
   ```

3. **Update flake.nix** to add the new host target

4. **Stage and verify:**
   ```bash
   git add nix/hosts/<new-hostname>/
   nix flake check --no-build
   ```

See `nix/docs/00-architecture.md` for full host configuration details.
