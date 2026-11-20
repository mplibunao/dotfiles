# Dotfiles Mapping

How configuration files reach the home directory through Home Manager, and which files stay outside it. [`CODING_STANDARDS.md`](../../CODING_STANDARDS.md#home-manager-modules-and-file-mappings) says which mechanism to choose.

---

## Mechanisms

Home Manager writes a configuration file in one of three ways:

- A **program module** (`programs.<name>`) generates the file from typed options. It gives type-checked settings, sensible defaults, integration with other modules, and documentation through `man home-configuration.nix`.
- **`xdg.configFile`** maps a file under `~/.config/`.
- **`home.file`** maps any other file under the home directory.

By default a mapped file is copied into the Nix store at build time, and the home-directory path is a read-only link to that copy. `config.lib.file.mkOutOfStoreSymlink` instead links the path straight to this checkout, so an edit takes effect without a rebuild. [ADR-019](../decisions/019-store-managed-file-mappings-by-default.md) sets the criteria for that exception.

---

## Dotfile Locations

### Files Managed by Program Modules

| Dotfile | Module | File |
|---------|--------|------|
| `~/.config/git/config` | `programs.git`, `programs.delta` | `modules/git/default.nix` |
| `~/.config/fish/*` | `programs.fish` | `modules/fish/default.nix` |
| `~/.config/starship.toml` | `programs.starship`, reading `starship.toml` beside the module | `modules/starship/default.nix` |
| `~/.ssh/config` | `programs.ssh` | `modules/ssh/default.nix` |
| `~/.config/bat/*` | `programs.bat` | `modules/bat/default.nix` |
| `~/.config/kitty/kitty.conf` | `programs.kitty` | `modules/kitty/default.nix` ([Kitty](kitty.md)) |
| `~/.config/aerospace/aerospace.toml` | `programs.aerospace`, reading `aerospace.toml` beside the module | `modules/aerospace/default.nix` ([AeroSpace](aerospace.md)) |

### Files Managed via xdg.configFile and home.file

| Dotfile | Source | Mapping |
|---------|--------|---------|
| `~/.config/opencode/opencode.jsonc` | `modules/llm-tools/opencode.jsonc` | `xdg.configFile` in `modules/llm-tools/default.nix` |
| `~/.cursor/mcp.json` | `modules/llm-tools/cursor-mcp.json` | `home.file` in `modules/llm-tools/default.nix` |
| `~/.local/bin/opencode` | Pinned upstream package in `/nix/store` | `home.file` in `modules/llm-tools/default.nix` |
| `~/Library/LaunchAgents/com.mp.executor.plist` | Generated in `modules/executor/default.nix` | `home.file` in the same module |

Home Manager store-manages only `~/.config/opencode/opencode.jsonc` through `xdg.configFile`; its local authentication file and configuration directory remain outside Home Manager ownership. Cursor's exact-file mapping preserves the existing direct RepoPrompt entry and adds Executor. See [ADR-023](../decisions/023-opencode-cursor-client-config-ownership.md) for the ownership boundary and activation sequence.

The OpenCode executable entry is a store-managed link to the same immutable executable installed by Tier 1. It is a RepoPrompt GUI discovery bridge, not a wrapper or second package. Unlike ADR-012's `mkOutOfStoreSymlink` shims for frequently edited repository scripts, this mapping follows ADR-019's store-managed default. Activation requires one intended executable, no higher-priority competitor, and no `force = true` collision bypass; follow the canonical [prerequisite and collision procedure](runbooks/opencode-repoprompt.md#opencode-prerequisites-collisions).

### Files Linked out of the Store

These paths point into a working checkout through `mkOutOfStoreSymlink`, so editing the repository file changes the live one. All but the last row point into this repository:

| Path | Repository file | Module |
|------|-----------------|--------|
| `~/.config/karabiner` | `modules/karabiner/config/` | `modules/karabiner/default.nix` |
| `~/.config/fish/functions` | `modules/fish/functions/` ([Fish](fish.md)) | `modules/fish/default.nix` |
| `~/.config/tinycast/settings.json` | `modules/tinycast/settings.json` ([TinyCast](tinycast.md)) | `modules/tinycast/default.nix` |
| `~/.cloudflared/config.yml` | `modules/cloudflared/config.yml` | `modules/cloudflared/default.nix` |
| `~/.local/bin/nix-ops`, `nix-verify`, `nix-locate`, `claude-proxy-route`, `cli-proxy-dashboard-setup` | `scripts/` | `modules/nix-ops-tools/default.nix` |
| `~/.local/bin/claude-launch`, `codex-launch` | `scripts/` in the claude-toolkit checkout, `~/Projects/personal/ai/claude-toolkit` | `modules/llm-tools/default.nix` |

---

## Program Module Examples

These show how each option is written. The current configuration is in the modules named in the tables above.

### Git

```nix
# modules/git/default.nix
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
# modules/fish/default.nix
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
# modules/starship/default.nix
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

## File Mapping Example

For an app with no Home Manager module, map its file from the module folder or write it inline:

```nix
# modules/myapp/default.nix
{ config, ... }:
{
  # Option 1: source from a file beside the module
  xdg.configFile."myapp/config".source = ./config;

  # Option 2: inline text
  xdg.configFile."myapp/config".text = ''
    setting = value
  '';

  # A file outside ~/.config
  home.file.".myapprc".source = ./myapprc;
}
```

---

## Adding a Mapping

1. **Find the file.** Check which configuration file the app reads, for example `~/.config/myapp/config`.
2. **Check for a Home Manager module.** Search the options with `man home-configuration.nix | grep -i myapp`, or at https://home-manager-options.extranix.com/.
3. **Write the module** in `modules/myapp/default.nix`, using `programs.myapp` when a module exists and a file mapping otherwise.
4. **Import it** in `home/mp/darwin.nix`:

   ```nix
   imports = [
     ../../modules/myapp
   ];
   ```

5. **Stage and build** it with the [command ladder](command-ladder.md).

If activation stops because a file is already in the way, follow [Activation Errors](troubleshooting.md#file-is-in-the-way) in Troubleshooting.

On a fresh machine, don't create configuration files by hand for things Home Manager will manage. Let it generate them first, and add local overrides through Home Manager options.

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
| `~/.config/executor-gateway/scope`, `~/.local/state/executor` | Executor workspace and service logs; `modules/executor/default.nix` only creates the folders (mode 0700) |
| IDE project settings | Local preferences |

RepoPrompt normal OpenCode launches use a process-ephemeral MCP overlay. Keep `mcp.RepoPromptCE` out of persistent configuration and keep OpenCode credentials outside Home Manager. The exact-file mapping retains non-secret model defaults while per-session choices remain operator-owned. Follow the canonical [ephemeral-MCP and persistent-entry cleanup procedure](runbooks/opencode-repoprompt.md#opencode-ephemeral-mcp).

---

## Quick Reference

| Config Type | HM Mechanism | Example |
|-------------|--------------|---------|
| Has HM module | `programs.<name>` | `programs.git.enable = true;` |
| `~/.config/*` | `xdg.configFile` | `xdg.configFile."app/config".source = ./config;` |
| `~/*` | `home.file` | `home.file.".somerc".source = ./somerc;` |
| Inline text | `.text` | `home.file.".somerc".text = "";` |
| Live link to this checkout | `config.lib.file.mkOutOfStoreSymlink` | ADR-019 exceptions only |
