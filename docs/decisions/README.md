# Decisions

Architecture decision records (ADRs) for this configuration, one file each. [Docs and records](../architecture/docs-and-records.md#adrs) says when a decision gets one.

## Format

- Filenames: `NNN-kebab-case-slug.md` (numeric prefix matches the ADR number).
- Sections: see [`template.md`](template.md).
- Status values: `proposed`, `accepted`, `superseded`.
- Dates: `YYYY-MM-DD`.
- To replace a decision, write a new ADR. Set the old one's status to `superseded by [ADR-NNN](NNN-slug.md)` and update its row below. Leave the rest of the old ADR as it was.

## Entries

| ADR | Title | Status |
|-----|-------|--------|
| [001](001-determinate-nix.md) | Use Determinate Nix instead of upstream | accepted |
| [002](002-home-manager-as-nix-darwin-module.md) | Home Manager as a nix-darwin module (not standalone) | accepted |
| [003](003-nixpkgs-branch-for-darwin.md) | Nixpkgs branch for Darwin | superseded by [008](008-nixpkgs-unstable-nix-darwin-master.md) |
| [004](004-nodejs-via-fnm.md) | Node.js via fnm (Fast Node Manager) | superseded by [020](020-nodejs-via-mise.md) |
| [005](005-gui-apps-via-homebrew-casks.md) | GUI apps via Homebrew casks | accepted (revised by [016](016-homebrew-formulae-for-third-party-tap-tools.md)) |
| [006](006-aerospace-instead-of-yabai.md) | AeroSpace instead of Yabai | accepted |
| [007](007-package-tiers-for-closure-management.md) | Package tiers for closure management | accepted |
| [008](008-nixpkgs-unstable-nix-darwin-master.md) | Move to nixpkgs-unstable + nix-darwin master | accepted |
| [009](009-fish-functions-symlink-strategy.md) | Fish functions symlink strategy | superseded by [019](019-store-managed-file-mappings-by-default.md) |
| [010](010-canonical-agent-instructions-at-nix-agents-md.md) | Canonical agent instructions at nix/AGENTS.md | superseded by [027](027-thin-root-router-and-docs-by-topic.md) |
| [011](011-canonical-operational-scripts-in-dotfiles-nix-scripts.md) | Canonical operational scripts in dotfiles/nix/scripts/ | accepted |
| [012](012-script-exposure-via-local-bin-shims.md) | Script exposure via HM-managed shims in ~/.local/bin | accepted (exception in [022](022-codexbar-profile-home-merge-boundary.md)) |
| [013](013-aerospace-config-via-nix-not-file-import.md) | AeroSpace config via Nix (not file import) | superseded by [014](014-aerospace-toml-as-canonical-authored-config.md) |
| [014](014-aerospace-toml-as-canonical-authored-config.md) | AeroSpace TOML as canonical authored config | accepted |
| [015](015-manually-managed-gui-apps-system.md) | Manually managed GUI apps system | accepted (tool retired 2026-11-20; see its note) |
| [016](016-homebrew-formulae-for-third-party-tap-tools.md) | Homebrew formulae for third-party tap tools | accepted |
| [017](017-aerospace-keepalive-false-for-gaming-mode.md) | AeroSpace KeepAlive=false for gaming mode | accepted |
| [018](018-full-access-codex-abbreviations-in-fish.md) | Full-access Codex abbreviations in Fish | accepted |
| [019](019-store-managed-file-mappings-by-default.md) | Store-managed file mappings by default, out-of-store symlinks by exception | accepted |
| [020](020-nodejs-via-mise.md) | Node.js via mise | accepted (supersedes [004](004-nodejs-via-fnm.md)) |
| [021](021-opencode-upstream-flake-for-repoprompt-acp.md) | Use the upstream OpenCode flake for RepoPrompt ACP | accepted |
| [022](022-codexbar-profile-home-merge-boundary.md) | CodexBar profile-home merge boundary | accepted |
| [023](023-opencode-cursor-client-config-ownership.md) | Exact-file ownership for OpenCode and Cursor client configuration | accepted (supersedes [021](021-opencode-upstream-flake-for-repoprompt-acp.md) point 4 only) |
| [024](024-phone-harness-installation-ownership.md) | Keep Phone Harness in a uv-managed environment | accepted |
| [025](025-opencode-node-modules-hash-override.md) | Override a stale OpenCode node_modules hash locally | accepted (revises [021](021-opencode-upstream-flake-for-repoprompt-acp.md) point 2 only) |
| [026](026-cliproxyapi-prebuilt-launchagent.md) | Prebuilt CLIProxyAPI release, local dashboard checkout | accepted |
| [027](027-thin-root-router-and-docs-by-topic.md) | Thin root router and docs by topic | accepted (supersedes [010](010-canonical-agent-instructions-at-nix-agents-md.md)) |

## History

ADRs 001–018 started in one decisions log. On 2026-04-27 they were split into one file each, alongside ADR-019, and reshaped to the template's sections. The old `Rationale` sections and ad hoc tail sections were folded into the matching sections, a `Migration` and a `Risks` section were added to each (`N/A` for decisions about behavior only), and status values were lowercased. Two changes went beyond format: ADR-009's status became superseded by ADR-019, and ADR-016's examples gained `rtk`.

ADRs before 027 name paths from before the flake moved to the repository root, such as `nix/scripts/`. [ADR-027](027-thin-root-router-and-docs-by-topic.md#migration) maps them to the current paths.
