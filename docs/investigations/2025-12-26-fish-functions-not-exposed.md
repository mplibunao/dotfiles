# Investigation: Fish Shell Functions Not Exposed in Nix Migration

## Summary

Fish functions from the old dotfiles are not available on the new machine because the Nix Home Manager fish.nix module does not include the functions from `dotfiles/fish/functions/`. The old setup relied on an imperative model where functions were symlinked or copied, while the new Nix approach requires explicitly declaring functions in the configuration.

## Symptoms

- `clm` function not found (Claude MCP Launcher)
- `findandkill` function not found (kill process on port)
- Other functions from `dotfiles/fish/functions/` unavailable
- Functions directory at `~/.config/fish/functions/` is empty

## Investigation Log

### Phase 1 - Initial Assessment

**Hypothesis:** Functions are not being copied/symlinked to the new machine's fish config.

**Findings:**
1. On new machine: `~/.config/fish/functions/` is empty
2. Old dotfiles contain functions in:
   - `dotfiles/fish/functions/*.fish` (7 files)
   - `dotfiles/fish/functions/a_mp/*.fish` (5 files - user-specific)
3. Nix fish.nix module at `nix/home/mp/modules/fish.nix` does NOT include:
   - `programs.fish.functions` definitions
   - `xdg.configFile."fish/functions"` symlinks
   - Any reference to the original functions

**Evidence:**
- `fish.nix:1-152` - No functions defined
- `~/.config/fish/functions/` - Empty directory

**Conclusion:** CONFIRMED - Functions are not being ported to Nix configuration

### Phase 2 - Understanding the Old Setup

**Hypothesis:** Old setup used conf.d and function path manipulation.

**Findings:**
1. `conf.d/05-custom-functions.fish` added `functions/a_mp` to `fish_function_path`:
   ```fish
   set -p fish_function_path $__fish_config_dir/functions/a_mp
   ```
2. `conf.d/50-abbreviations.fish` auto-loaded abbreviations via `setup-abbreviations`
3. Old dotfiles had these functions:
   - `clm.fish` - Claude MCP Launcher with completions
   - `findandkill.fish` - Kill process on port
   - `fish_greeting.fish` - Custom greeting (disabled)
   - `secret.fish` - Generate random secrets
   - `setup-abbreviations.fish` - Abbreviation definitions
   - `setup-fish.fish` - One-time setup (imperative)
   - `setup-tide-theme.fish` - Theme setup (not needed with Starship)
   - `starship_transient_prompt_func.fish` - Transient prompt support

4. Functions in `a_mp/` subdirectory (custom namespaced functions):
   - `kdev.fish` - Kitty development layout
   - `kt.fish` - Kitty tab management
   - `nvim-config.fish` - Switch Neovim configs
   - `switch-to-starship.fish` - Switch to Starship prompt
   - `switch-to-tide.fish` - Switch to Tide prompt

**Conclusion:** The old system required:
1. Running `setup-fish` imperatively to set up paths and env vars
2. conf.d scripts to auto-load abbreviations and add function paths
3. Functions to exist in the functions directory

### Phase 3 - Imperative Setup Functions That Need Declarative Migration

**Hypothesis:** Some setup functions contain one-time configuration that should be declarative.

**Analysis of `setup-fish.fish`:**

| Element | Old Approach | Nix Approach | Status |
|---------|--------------|--------------|--------|
| PATH entries | `fish_add_path --universal` | `home.sessionPath` | PARTIAL - missing some paths |
| EDITOR | `set -Ux EDITOR nvim` | `home.sessionVariables` | PARTIAL - in common.nix |
| DOTFILES_DIR | `set -Ux DOTFILES_DIR` | `home.sessionVariables` | DONE |
| VOLTA_HOME | `set -Ux VOLTA_HOME` | Not needed - using fnm | N/A |
| PNPM_HOME | `set -Ux PNPM_HOME` | Needs adding | MISSING |
| Completions (kubectl, gcloud) | Generate imperatively | Need to generate or use packages | MISSING |
| fish_greeting | `set -U fish_greeting ""` | `set -g fish_greeting` in shellInit | DONE |

**Analysis of conf.d scripts that need porting:**

| File | Purpose | Nix Approach | Status |
|------|---------|--------------|--------|
| `05-custom-functions.fish` | Add a_mp to function path | `programs.fish.functions` or file copy | MISSING |
| `10-env.fish` | FZF_DEFAULT_OPTS, Docker vars | `home.sessionVariables` or interactiveShellInit | MISSING |
| `20-keybindings.fish` | Vi mode bindings | `programs.fish.interactiveShellInit` | MISSING |
| `30-auto-ls.fish` | Auto-ls after cd | Optional, low priority | SKIP |
| `50-abbreviations.fish` | Load abbreviations | Already done via shellAbbrs | DONE |

**Conclusion:** Several conf.d configurations need porting

## Root Cause

The Nix fish.nix module is incomplete. It successfully migrated:
- Shell abbreviations (via `shellAbbrs`)
- Interactive shell initialization (starship, zoxide)
- Plugins (fzf-fish, autopair)

But it did NOT migrate:
1. **Custom functions** - Must use `programs.fish.functions` or `xdg.configFile`
2. **Environment variables** - FZF_DEFAULT_OPTS, Docker settings from conf.d/10-env.fish
3. **Additional session paths** - PNPM_HOME, npm-global, cargo, etc.

## Recommendations

### Option 1: Declare Functions in Nix (Recommended)

Add to `fish.nix`:

```nix
programs.fish = {
  functions = {
    findandkill = builtins.readFile ../../../fish/functions/findandkill.fish;
    clm = builtins.readFile ../../../fish/functions/clm.fish;
    secret = builtins.readFile ../../../fish/functions/secret.fish;
    # ... other functions
  };
};
```

**Pros:** Fully declarative, tracked in Nix
**Cons:** Need to parse function body from file (may need tweaks), completions need separate handling

### Option 2: Symlink Functions Directory

Add to `darwin.nix` or create a new module:

```nix
xdg.configFile = {
  "fish/functions/clm.fish".source = ../../../fish/functions/clm.fish;
  "fish/functions/findandkill.fish".source = ../../../fish/functions/findandkill.fish;
  # ... etc
};
```

**Pros:** Simple, reuses existing files
**Cons:** Doesn't leverage Nix's function syntax, files outside nix/ directory

### Option 3: Symlink Entire Directory + Function Path

```nix
xdg.configFile."fish/functions/a_mp".source = ../../../fish/functions/a_mp;

programs.fish.interactiveShellInit = ''
  set -p fish_function_path $__fish_config_dir/functions/a_mp
  # ... rest
'';
```

**Pros:** Mirrors old setup, minimal changes
**Cons:** Half-declarative approach

## Immediate Fixes Needed

1. **Add functions to fish.nix** - Use Option 1 or 2
2. **Add environment variables** - Port 10-env.fish settings:
   ```nix
   home.sessionVariables = {
     FZF_DEFAULT_OPTS = "...catppuccin theme...";
     COMPOSE_DOCKER_CLI_BUILD = "1";
     DOCKER_BUILDKIT = "1";
     USE_GKE_GCLOUD_AUTH_PLUGIN = "True";
   };
   ```
3. **Add missing PATH entries to common.nix**:
   ```nix
   home.sessionPath = [
     "$HOME/.local/bin"
     "$HOME/.npm-global/bin"
     "$HOME/.cargo/bin"
     "$HOME/Library/pnpm"
   ];
   ```

## Preventive Measures

1. **Create a migration checklist** for fish configuration elements
2. **Document which functions are user-specific vs utilities**
3. **Consider splitting functions into tiers** like packages:
   - Tier 1: Essential (clm, findandkill)
   - Tier 2: Kitty-specific (kt, kdev)
   - Tier 3: Development (nvim-config, setup-*)
