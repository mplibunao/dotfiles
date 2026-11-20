# Packages and Tiers

Packages are organized into tiers by urgency and necessity, which keeps the closure from growing by accident ([ADR-007](../decisions/007-package-tiers-for-closure-management.md)).

---

## Source of Truth

The Nix files list the packages and apps, so this document doesn't. When in doubt, read them:

| What | File |
|------|------|
| Tier 1 packages | [`home/mp/package-tiers/tier1.nix`](../../home/mp/package-tiers/tier1.nix) |
| Tier 2 packages | [`home/mp/package-tiers/tier2.nix`](../../home/mp/package-tiers/tier2.nix) |
| Casks and the allowed Homebrew brews | [`hosts/m5-mbp/homebrew.nix`](../../hosts/m5-mbp/homebrew.nix), described in [GUI apps](gui-apps.md). Its numbered group comments aren't these tiers. |

Only Tiers 1 and 2 have files.

A Home Manager program module installs some tools together with their configuration, so they aren't in a tier file: [Fish](../../modules/fish/default.nix), [Starship](../../modules/starship/default.nix), [Git and Delta](../../modules/git/default.nix), [Neovim](../../modules/neovim/default.nix), and [bat](../../modules/bat/default.nix).

A few tools don't come from Nix at all. The [bootstrap runbook](../../.claude/skills/bootstrap/references/bootstrap-runbook.md#claude-code) sets up Claude Code and Codex, [Surf CLI](runbooks/surf-cli.md) follows its own runbook, and the CLIProxyAPI dashboard is a local checkout that [its runbook](runbooks/cli-proxy-api.md) covers.

## Tier Philosophy

| Tier | Priority | When to Install | Closure Impact |
|------|----------|-----------------|----------------|
| 1 | Essential | Day 1 | Minimal, highly optimized |
| 2 | Development | Day 2-3 | Moderate, project-specific |
| 3 | Nice-to-have | Week 1 | Can be large, evaluate carefully |
| Evaluate | Unknown | TBD | Don't install until justified |

[`CODING_STANDARDS.md`](../../CODING_STANDARDS.md#packages) says which tier a new package goes in.

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

## Adding New Packages

### Process

1. **Choose the tier and write the comment** by the rules in [Coding standards](../../CODING_STANDARDS.md#packages)
2. **Check availability** on Darwin
3. **Edit the tier file**
4. **For independently pinned flake packages, review the source tag and lock graph**
5. **Check the change** with the [command ladder](command-ladder.md)

### Example

To add `httpie`, check that it exists for Darwin with `nix search nixpkgs#httpie`, then add one line to the `home.packages` list in `home/mp/package-tiers/tier2.nix`:

```nix
    httpie # HTTP client
```

After the approved switch, `which http` finds it.

---

## Removing Packages

### Process

1. Remove the package declaration from its tier file.
2. Check the change with the [command ladder](command-ladder.md) through the build, which doesn't activate it.
3. After review and explicit operator approval, follow the [approval-gated activation procedure](command-ladder.md#level-4-apply).
4. After activation and validation, use the [storage management guide](storage.md) to decide whether to clean up storage.

Treat cleanup as a separate decision, because some cleanup commands also delete rollback generations. [Storage](storage.md#aggressive-gc) says which command deletes what. Never manually delete paths from `/nix/store`.
