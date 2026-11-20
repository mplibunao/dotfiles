# Packages and Tiers

Packages are organized into tiers by urgency and necessity, which keeps the closure from growing by accident ([ADR-007](../decisions/007-package-tiers-for-closure-management.md)).

---

## Source of Truth

**The tier files (`home/mp/package-tiers/tier*.nix`) are canonical.** The tables below are illustrative examples and may drift. When in doubt, check the actual tier files.

## Tier Philosophy

| Tier | Priority | When to Install | Closure Impact |
|------|----------|-----------------|----------------|
| 1 | Essential | Day 1 | Minimal, highly optimized |
| 2 | Development | Day 2-3 | Moderate, project-specific |
| 3 | Nice-to-have | Week 1 | Can be large, evaluate carefully |
| Evaluate | Unknown | TBD | Don't install until justified |

[`CODING_STANDARDS.md`](../../CODING_STANDARDS.md#packages) says which tier a new package goes in.

---

## Tier 1: Essential (Day 1)

Core tools needed to be productive immediately.

### Shell & Prompt

| Package | Nix Name | Purpose |
|---------|----------|---------|
| Fish | `fish` | Primary shell |
| Starship | `starship` | Cross-shell prompt |
| Fisher | via fish plugins | Plugin manager |

### Version Control

| Package | Nix Name | Purpose |
|---------|----------|---------|
| Git | `git` | VCS |
| Delta | `delta` | Git pager with syntax highlighting |

### Editor

| Package | Nix Name | Purpose |
|---------|----------|---------|
| Neovim | `neovim` | Primary editor |

### Modern CLI Replacements

| Package | Replaces | Nix Name | Purpose |
|---------|----------|----------|---------|
| bat | cat | `bat` | Syntax-highlighted file viewing |
| lsd | ls | `lsd` | Modern ls with icons |
| fd | find | `fd` | Fast file finder |
| ripgrep | grep | `ripgrep` | Fast search |
| fzf | - | `fzf` | Fuzzy finder |
| zoxide | cd | `zoxide` | Smart directory jumping |

### Terminal

| Package | Nix Name | Notes |
|---------|----------|-------|
| Kitty | - | Installed via Homebrew cask; config via HM |

### LLM Tools

| Package | Install Method | Notes |
|---------|---------------|-------|
| claude-code | curl script | See bootstrap skill |
| codex | npm global | `@openai/codex` |
| Surf CLI | npm global | Official `surf-cli`; see [setup and upgrades](runbooks/surf-cli.md) |
| OpenCode | Pinned upstream flake (tier1.nix) | RepoPrompt CE Agent Mode/MCP via ACP; see [ADR-021](../decisions/021-opencode-upstream-flake-for-repoprompt-acp.md) |
| CLIProxyAPI | Pinned release tarball | LaunchAgent on 127.0.0.1:8317; see [ADR-026](../decisions/026-cliproxyapi-prebuilt-launchagent.md) |
| cli-proxy-dashboard | Local pnpm checkout | Private repo, not a Nix package; see [the runbook](runbooks/cli-proxy-api.md) |

Note: claude-code uses the official curl installer, and codex requires npm. OpenCode uses a pinned upstream release with an independent lock graph for RepoPrompt ACP compatibility. Nix owns its executable and RepoPrompt GUI discovery bridge; authentication, provider/model configuration, and OpenCode application data remain mutable local state outside package ownership.

---

## Tier 2: Development (Day 2-3)

Project-specific development tools.

### Package Managers

| Package | Nix Name | Purpose |
|---------|----------|---------|
| pnpm | Corepack via mise-managed Node | Repo-local package manager pins |
| bun | `bun` | JS runtime + toolkit |
| uv | `uv` | Python package manager |

### Code Search / Rewrite

| Package | Nix Name | Purpose |
|---------|----------|---------|
| ast-grep | `ast-grep` | Structural search/rewriter |

### Infrastructure

| Package | Nix Name | Purpose | Notes |
|---------|----------|---------|-------|
| Terraform | `terraform` | IaC | Check license (BSL) |
| terraform-ls | `terraform-ls` | LSP for Terraform | |
| tflint | `tflint` | Terraform linter | |
| gcloud | `google-cloud-sdk` | GCP CLI | |
| cloudflared | `cloudflared` | Cloudflare tunnel | Local demos via named tunnel |

### Databases

| Package | Nix Name | Purpose |
|---------|----------|---------|
| PostgreSQL | `postgresql` | Client and libs |

### Data Processing

| Package | Nix Name | Purpose |
|---------|----------|---------|
| jq | `jq` | JSON processor |
| yq | `yq` | YAML processor |

### TUI Tools

| Package | Nix Name | Purpose |
|---------|----------|---------|
| lazygit | `lazygit` | Git TUI |
| lazydocker | `lazydocker` | Docker TUI |

### Containers

| Package | Nix Name | Notes |
|---------|----------|-------|
| Docker Desktop | - | Installed via Homebrew cask (see gui-apps.md) |

---

## Tier 3: Nice-to-Have (Week 1)

Quality of life improvements, lower priority.

### System Monitoring

| Package | Nix Name | Purpose |
|---------|----------|---------|
| bottom | `bottom` | System monitor (btm) |
| ncdu | `ncdu` | Disk usage analyzer |
| duf | `duf` | Disk usage |

### Media

| Package | Nix Name | Purpose |
|---------|----------|---------|
| ffmpeg | `ffmpeg` | Video/audio processing |
| imagemagick | `imagemagick` | Image processing |

### Utilities

| Package | Nix Name | Purpose |
|---------|----------|---------|
| tree | `tree` | Directory listing |
| watch | `watch` | Periodic execution |
| parallel | `parallel` | Parallel execution |

### Window Management

| Package | Notes |
|---------|-------|
| AeroSpace | Nix package (`pkgs.aerospace`) through `programs.aerospace`; config via HM |
| Karabiner-Elements | Installed via Homebrew cask; config via HM |

---

## Evaluate: Not Sure Yet

These packages require justification before installation.

### Cloud CLIs (Project-Specific)

| Package | Status | Notes |
|---------|--------|-------|
| doctl | Evaluate | DigitalOcean - rarely used |
| pscale | Evaluate | PlanetScale - project-specific |

### Database Clients (Project-Specific)

| Package | Status | Notes |
|---------|--------|-------|
| mysql-client | Evaluate | Only if project needs it |
| mongosh | Evaluate | Only if project needs it |
| redis | Evaluate | Only if project needs it |

### Legacy Tools

| Package | Status | Notes |
|---------|--------|-------|
| asdf | Skip | Use Nix devShells instead |
| ranger | Skip | Rarely used based on history |
| ansible | Skip | Not using currently |
| cowsay-apj | Optional | vim start screen fun |

---

## Skip List (Do Not Port)

These are explicitly excluded from the Nix config.

| Item | Reason |
|------|--------|
| yabai | Replacing with AeroSpace |
| skhd | Replacing with AeroSpace |
| zsh | Migrated to Fish |
| oh-my-zsh | Migrated to Fish |
| neofetch | Use fastfetch instead |
| hammerspoon | Never fully configured |
| asdf | Use Nix devShells |

---

## Darwin Package Availability

Some packages behave differently or are unavailable on macOS.

### Known Darwin Differences

| Package | Issue | Workaround |
|---------|-------|------------|
| Docker | No Nix package for macOS | Install Docker Desktop via Homebrew cask (see gui-apps.md) |
| Some GUI apps | Limited Nix support | Use Homebrew cask (see gui-apps.md) |
| Linux-only tools | Not available | Check availability before adding |

### Checking Availability

Before adding a package, verify it exists for Darwin:

```bash
# Search for package
nix search nixpkgs#<package>

# Check supported systems
nix eval nixpkgs#<package>.meta.platforms
```

---

## File Structure

Packages are organized in `home/mp/package-tiers/`:

```nix
# tier1.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Shell & Prompt
    fish
    starship

    # Git
    git
    delta

    # Editor
    neovim

    # Modern CLI
    fzf
    ripgrep
    fd
    bat
    lsd
    zoxide
  ];
}
```

```nix
# tier2.nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Package managers
    bun
    # pnpm is Corepack-managed per repo, not installed by Nix.
    uv

    # Infrastructure
    terraform
    terraform-ls
    tflint
    google-cloud-sdk

    # Database
    postgresql

    # TUI Tools
    lazydocker

    # Code search / rewrite
    ast-grep

    # File watching
    fswatch
  ];
}
```

---

## Adding New Packages

### Process

1. **Determine tier** based on urgency
2. **Check availability** on Darwin
3. **Edit appropriate tier file**
4. **Document the addition** (comment with purpose)
5. **For independently pinned flake packages, review the source tag and lock graph**
6. **Rebuild and verify**

### Example

To add `httpie`, check that it exists for Darwin with `nix search nixpkgs#httpie`, then add one line to the `home.packages` list in `home/mp/package-tiers/tier2.nix`:

```nix
    httpie # HTTP client
```

Build it with the [command ladder](command-ladder.md). After the approved switch, `which http` finds it.

---

## Removing Packages

### Process

1. Remove the package declaration from its tier file.
2. Run `nix-verify --to 2 --host <hostname>`. See the [command ladder](command-ladder.md). This checks the configuration without activating it.
3. After review and explicit operator approval, follow the [approval-gated activation procedure](command-ladder.md#level-4-apply).
4. After activation and validation, use the [storage management guide](storage.md) to decide whether to clean up storage.

Ordinary `nix-collect-garbage` removes unreachable store paths. The `-d` form and explicit generation deletion also remove rollback generations. Treat cleanup as a separate decision, and never manually delete paths from `/nix/store`.
