# Dotfiles

> **Migration in Progress**: This repo is transitioning to Nix (nix-darwin + Home Manager).
> Legacy scripts and configs outside `nix/` are deprecated.

Personal macOS configuration managed with Nix for reproducible, declarative system setup.

## Quick Start (Fresh Mac)

1. **Check your current phase:**
   ```bash
   .claude/skills/bootstrap/scripts/bootstrap-check.sh
   ```

2. **Follow the bootstrap guide:**
   - See [`.claude/skills/bootstrap/SKILL.md`](.claude/skills/bootstrap/SKILL.md)
   - Or use Claude Code: run `/bootstrap`

3. **For existing Nix setups:**
   ```bash
   cd nix
   darwin-rebuild build --flake .#m5-mbp  # Build (safe)
   sudo darwin-rebuild switch --flake .#m5-mbp  # Apply
   ```

## What's Included

| Category | Tools |
|----------|-------|
| Shell | Fish + Starship prompt |
| Terminal | Kitty |
| Editor | Neovim (LazyVim) |
| Git | Delta, lazygit |
| Window Manager | AeroSpace |
| Package Manager | Nix + Homebrew (GUI apps) |

## Project Structure

```
dotfiles/
├── nix/                    # Nix configuration (active)
│   ├── flake.nix           # Entry point
│   ├── hosts/m5-mbp/       # Host-specific config
│   ├── home/mp/            # User packages and dotfiles
│   └── docs/               # Nix documentation
│
├── .claude/                # Claude Code integration (hidden)
│   └── skills/bootstrap/   # Bootstrap automation
│
├── .beads/                 # Issue tracking (hidden)
│
├── keybinds/               # Keybind conflict detection
│
└── [legacy dirs]           # Deprecated (fish/, kitty/, etc.)
```

**Note:** `.claude/` and `.beads/` are hidden directories. They contain:
- `.claude/skills/bootstrap/` - Nix bootstrap automation
- `.beads/` - Local issue tracking with bd/beads

## Documentation

| Topic | Location |
|-------|----------|
| Nix Quick Start | [`nix/README.md`](nix/README.md) |
| Agent Instructions | [`nix/AGENTS.md`](nix/AGENTS.md) |
| Architecture | [`nix/docs/00-architecture.md`](nix/docs/00-architecture.md) |
| Migration Phases | [`nix/docs/01-migration-phases.md`](nix/docs/01-migration-phases.md) |
| Bootstrap Guide | [`.claude/skills/bootstrap/SKILL.md`](.claude/skills/bootstrap/SKILL.md) |

## For Forkers

If you fork this repo, update these values before bootstrapping:

1. **GitHub username** in clone URLs
2. **Email** for SSH key generation
3. **Hostname** in flake commands (run `hostname -s` to get yours)

See the bootstrap guide for a personalization checklist.

---

<details>
<summary>Legacy Documentation (deprecated)</summary>

The content below is from the original README and may not work with the current Nix-based setup.

### Legacy Setup (Not Recommended)

The old `bootstrap.sh` script is deprecated. Running it will show a warning and offer to continue anyway.

### Legacy Configs

These directories contain old configurations that are being migrated to Nix:

- `fish/` - Fish shell config (migrated to `nix/home/mp/modules/fish/`)
- `kitty/` - Kitty terminal config (migrated to `nix/home/mp/modules/kitty/`)
- `zsh/` - Zsh config (replaced by Fish)
- `yabai/`, `skhd/` - Window manager (replaced by AeroSpace)
- `karabiner/` - Key remapping (preserved, still needed)

### Old Symlink Troubleshooting

If you encounter empty symlinks, use relative paths from the destination directory:

```bash
cd ~
ln -s Projects/personal/dotfiles/some/file .some-file
```

### Old Tool Notes

- **Ranger**: `pip3 install ueberzug` for image support (Linux)
- **Powerlevel9k/10k**: Replaced by Starship
- **oh-my-zsh**: Replaced by Fish

</details>
