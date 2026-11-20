# Dotfiles Mapping

> How existing dotfiles map to Home Manager configuration.

This document explains the strategy for migrating dotfiles from the legacy symlink-based approach to declarative Home Manager management.

---

## Mapping Strategy

### Priority Order

1. **Use Home Manager program modules** when available
2. **Use `xdg.configFile`** for `~/.config/*` files
3. **Use `home.file`** for other home directory files
4. **Keep manual** for files that change frequently or need local edits

> **Mutable vs store-managed:** the mappings above default to store-managed (sources copied into the Nix store at build time). For cases where edit→effect feedback matters more than rebuild-time immutability — operational scripts, shell helpers iterated frequently, app-rewritten configs — use `config.lib.file.mkOutOfStoreSymlink` instead. See [decisions/019-store-managed-file-mappings-by-default.md](decisions/019-store-managed-file-mappings-by-default.md) for the criteria and decision matrix.

### Why Prefer Program Modules?

Home Manager program modules provide:
- Type-checked configuration
- Default values and sensible defaults
- Integration with other modules
- Automatic dependency management
- Documentation via `man home-configuration.nix`

---

## Dotfile Locations

### Files Managed by HM Program Modules

| Dotfile | HM Module | Example |
|---------|-----------|---------|
| `~/.gitconfig` | `programs.git` | `programs.git.userName = "MP";` |
| `~/.config/fish/*` | `programs.fish` | `programs.fish.shellAbbrs = {...};` |
| `~/.config/starship.toml` | `programs.starship` | `programs.starship.settings = {...};` |
| `~/.ssh/config` | `programs.ssh` | `programs.ssh.matchBlocks = {...};` |
| `~/.config/bat/*` | `programs.bat` | `programs.bat.config = {...};` |
| `~/.config/lazygit/*` | `programs.lazygit` | `programs.lazygit.settings = {...};` |

### Files Managed via xdg.configFile

| Dotfile | Source Location | HM Mapping |
|---------|-----------------|------------|
| `~/.config/kitty/kitty.conf` | `modules/home/kitty/kitty.conf` | `xdg.configFile."kitty/kitty.conf".source` |
| `~/.config/kitty/current-theme.conf` | `modules/home/kitty/themes/...` | `xdg.configFile."kitty/current-theme.conf".source` |
| `~/.aerospace.toml` | `modules/darwin/aerospace/aerospace.toml` | `home.file.".aerospace.toml".source` |
| `~/.config/opencode/opencode.jsonc` | `modules/opencode.jsonc`; activated 2026-10-28 | `xdg.configFile."opencode/opencode.jsonc".source` (active) |

### Files Managed via home.file

| Dotfile | Source Location | HM Mapping |
|---------|-----------------|------------|
| `~/.aerospace.toml` | `modules/darwin/aerospace.toml` | `home.file.".aerospace.toml".source` |
| `~/.hushlogin` | - | `home.file.".hushlogin".text = "";` |
| `~/.local/bin/opencode` | Pinned upstream package in `/nix/store` | `home.file.".local/bin/opencode".source` in `modules/llm-tools.nix` |
| `~/Library/LaunchAgents/com.mp.executor.plist` | Generated in `modules/executor.nix` | `home.file."Library/LaunchAgents/com.mp.executor.plist".source` |
| `~/.cursor/mcp.json` | `home/mp/modules/cursor-mcp.json` | `home.file.".cursor/mcp.json".source` in `modules/llm-tools.nix` (active) |

Home Manager store-manages only `~/.config/opencode/opencode.jsonc` through `xdg.configFile`; its local authentication file and configuration directory remain outside Home Manager ownership. Cursor's exact-file mapping preserves the existing direct RepoPrompt entry and adds Executor. See [ADR-023](decisions/023-opencode-cursor-client-config-ownership.md) for the ownership boundary and activation sequence.

The OpenCode executable entry is a store-managed link to the same immutable executable installed by Tier 1. It is a RepoPrompt GUI discovery bridge, not a wrapper or second package. Unlike ADR-012's `mkOutOfStoreSymlink` shims for frequently edited repository scripts, this mapping follows ADR-019's store-managed default. Activation requires one intended executable, no higher-priority competitor, and no `force = true` collision bypass; follow the canonical [prerequisite and collision procedure](runbooks/opencode-repoprompt.md#opencode-prerequisites-collisions).

---

## Program Module Examples

### Git

```nix
# modules/home/git.nix
{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    userName = "MP";
    userEmail = "markpaololibunao@gmail.com";

    delta = {
      enable = true;
      options = {
        features = "decorations side-by-side line-numbers";
        navigate = true;
        syntax-theme = "Dracula";
      };
    };

    extraConfig = {
      init.defaultBranch = "main";
      rerere.autoupdate = true;
      core.excludesfile = "~/.gitignore";
    };

    ignores = [
      "*.log"
      ".DS_Store"
      "Thumbs.db"
      ".vscode"
      "node_modules"
      "dist"
      "build"
    ];
  };
}
```

### Fish

```nix
# modules/home/fish.nix
{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      v = "nvim";
      g = "git";
      ls = "lsd --hyperlink=auto";
      lt = "lsd --tree";
      p = "pnpm";
      lzg = "lazygit";
      lzd = "lazydocker";
    };

    shellInit = ''
      # Suppress greeting
      set -g fish_greeting
    '';

    interactiveShellInit = ''
      # Starship prompt
      starship init fish | source

      # Zoxide
      if type -q zoxide
        zoxide init fish | source
      end
    '';

    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
    ];
  };
}
```

### Starship

```nix
# modules/home/starship.nix
{ config, ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;

    settings = {
      add_newline = true;

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
      };

      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };
    };
  };
}
```

---

## File Mapping Examples

### Kitty Configuration

```nix
# modules/home/kitty.nix
{ config, ... }:
{
  # Option 1: Source from file
  xdg.configFile."kitty/kitty.conf".source = ./kitty/kitty.conf;
  xdg.configFile."kitty/current-theme.conf".source = ./kitty/themes/catppuccin-mocha.conf;

  # Option 2: Inline text
  xdg.configFile."kitty/kitty.conf".text = ''
    font_family Fira Code Retina
    font_size 12.0
    shell /run/current-system/sw/bin/fish
    editor nvim

    allow_remote_control yes
    macos_option_as_alt yes
    copy_on_select true

    include current-theme.conf
  '';
}
```

### AeroSpace Configuration

```nix
# modules/darwin/aerospace.nix
{ config, ... }:
{
  home.file.".aerospace.toml".source = ./aerospace/aerospace.toml;
}
```

Or with inline TOML:

```nix
{ config, ... }:
{
  home.file.".aerospace.toml".text = ''
    start-at-login = true
    enable-normalization-flatten-containers = true

    [gaps]
    inner.horizontal = 5
    inner.vertical = 5

    [mode.main.binding]
    alt-h = 'focus left'
    alt-j = 'focus down'
    alt-k = 'focus up'
    alt-l = 'focus right'
  '';
}
```

---

## Migration Workflow

### Step 1: Identify the Dotfile

```bash
# What config file am I migrating?
cat ~/.config/fish/config.fish
```

### Step 2: Check for HM Module

```bash
# Search options
man home-configuration.nix | grep -i fish
# Or check online: https://home-manager-options.extranix.com/
```

### Step 3: Create the Module

If HM module exists:
```nix
# modules/home/fish.nix
{ ... }:
{
  programs.fish = {
    enable = true;
    # Translate config to options
  };
}
```

If no HM module:
```nix
# modules/home/myapp.nix
{ ... }:
{
  xdg.configFile."myapp/config".source = ./myapp/config;
  # Or
  xdg.configFile."myapp/config".text = ''
    setting = value
  '';
}
```

### Step 4: Import in Home Config

```nix
# home/mp/darwin.nix
{ ... }:
{
  imports = [
    ../../modules/home/fish.nix
    ../../modules/home/git.nix
    ../../modules/home/kitty.nix
  ];
}
```

### Step 5: Handle Collisions

If existing file blocks activation:
```bash
# Move the old file
mv ~/.config/fish/config.fish ~/.config/fish/config.fish.backup

# Rebuild
# NOTE: This is a live-system apply (`switch`) and requires explicit approval.
sudo darwin-rebuild switch --flake .#<hostname>

# Compare and delete backup if satisfied
diff ~/.config/fish/config.fish ~/.config/fish/config.fish.backup
rm ~/.config/fish/config.fish.backup
```

---

## Collision Handling

Home Manager refuses to overwrite files it doesn't manage.

### Error Message

```
Existing file '/home/mp/.config/git/config' is in the way
Please move the above files and try again
```

### Resolution

1. **Backup the existing file**
   ```bash
   mv ~/.config/git/config ~/.config/git/config.backup
   ```

2. **Rebuild**
   ```bash
   # NOTE: This is a live-system apply (`switch`) and requires explicit approval.
   sudo darwin-rebuild switch --flake .#<hostname>
   ```

3. **Compare HM-generated with backup**
   ```bash
   diff ~/.config/git/config ~/.config/git/config.backup
   ```

4. **Merge any missing settings** into HM config if needed

5. **Delete backup**
   ```bash
   rm ~/.config/git/config.backup
   ```

### Prevention

On a fresh machine:
- Don't manually create configs for things HM will manage
- Let HM generate everything first
- Only add local overrides via HM options

---

## Source File Organization

```
nix/modules/home/
├── fish.nix              # Uses programs.fish
├── git.nix               # Uses programs.git
├── starship.nix          # Uses programs.starship
├── kitty.nix             # Uses xdg.configFile
├── kitty/
│   ├── kitty.conf        # Source file
│   └── themes/
│       └── catppuccin-mocha.conf
└── neovim.nix            # Minimal, actual config in separate repo

nix/modules/darwin/
├── aerospace.nix         # Uses home.file
├── aerospace/
│   └── aerospace.toml    # Source file
└── karabiner.nix         # Uses xdg.configFile
```

---

## What NOT to Manage via HM

Some files should remain manual:

| File | Reason |
|------|--------|
| `~/.ssh/id_*` | Private keys, generate per-machine |
| `~/.config/gh/hosts.yml` | Auth tokens, per-machine |
| `~/.config/gcloud/...` | Auth, per-machine |
| `.env` files | Secrets |
| `${XDG_DATA_HOME:-$HOME/.local/share}/opencode/auth.json` | OpenCode-owned credentials; must not enter Git or the Nix store |
| `~/.config/opencode` directory and project `opencode.json`/`.jsonc`/`.opencode` | App-owned and project configuration; only the global `opencode.jsonc` file has exact-file Home Manager ownership under ADR-023 |
| `~/.executor` | Executor-owned database and service access key; created by the service |
| `~/.local/share/executor` | Executor-owned upstream OAuth token store; back up and restore together with `~/.executor` |
| `~/.config/executor-gateway/scope`, `~/.local/state/executor` | Executor workspace and service logs; `modules/executor.nix` only creates the folders (mode 0700) |
| IDE project settings | Local preferences |

RepoPrompt normal OpenCode launches use a process-ephemeral MCP overlay. Keep `mcp.RepoPromptCE` out of persistent configuration and keep OpenCode credentials outside Home Manager. The exact-file mapping retains non-secret model defaults while per-session choices remain operator-owned. Follow the canonical [ephemeral-MCP and persistent-entry cleanup procedure](runbooks/opencode-repoprompt.md#opencode-ephemeral-mcp).

---

## Quick Reference

| Config Type | HM Mechanism | Example |
|-------------|--------------|---------|
| Has HM module | `programs.<name>` | `programs.git.enable = true;` |
| `~/.config/*` | `xdg.configFile` | `xdg.configFile."app/config".source = ./config;` |
| `~/*` | `home.file` | `home.file.".somerc".source = ./somerc;` |
| Inline text | `.text` | `home.file.".hushlogin".text = "";` |
