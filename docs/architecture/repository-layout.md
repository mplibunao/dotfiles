# Repository layout

The flake is at the repository root. Home Manager modules live in a directory per tool, `modules/<tool>/`, beside the files they read or link. A directory can contain more than one module: `modules/cli-proxy/` has `api.nix` and `dashboard.nix`.

```text
dotfiles/
├── flake.nix, flake.lock    # inputs and the darwinConfigurations."m5-mbp" output
├── hosts/m5-mbp/            # nix-darwin host
│   ├── configuration.nix    # host module: platform, users, Home Manager wiring
│   ├── defaults.nix         # macOS defaults and activation-time settings
│   └── homebrew.nix         # Homebrew casks and the few allowed brews
├── home/mp/
│   ├── common.nix           # common user settings, imported by darwin.nix
│   ├── darwin.nix           # macOS entry point; imports every module
│   └── package-tiers/       # tier1.nix and tier2.nix package lists
├── modules/<tool>/          # one or more modules plus the files they read or link
├── packages/                # custom derivations (callPackage targets)
├── scripts/                 # operational scripts, linked into ~/.local/bin
├── tests/                   # shell and Python tests for the scripts and modules
├── data/workspaces.toml     # AeroSpace workspace registry
├── docs/                    # architecture docs, ADRs, ledgers, investigations
├── .claude/                 # Claude Code commands and the bootstrap skill
├── .githooks/               # pre-commit and pre-push hooks (Docs and records, Hooks)
└── .github/workflows/       # CI on Linux: flake evaluation and a secret scan
```

[Overview](overview.md) explains how these layers fit together, and [Docs and records](docs-and-records.md) covers `docs/`.

## Where to add things

| Change | Where |
|---|---|
| A tier-managed package | `home/mp/package-tiers/tier1.nix` or `tier2.nix`; see [Packages and tiers](packages-and-tiers.md) |
| A Homebrew-managed app | `hosts/m5-mbp/homebrew.nix`; see [GUI apps](gui-apps.md) |
| A program's configuration | `modules/<tool>/default.nix`, imported from `home/mp/darwin.nix` |
| A file a module links or reads | Beside the module, in `modules/<tool>/` |
| A Fish abbreviation | `shellAbbrs` in `modules/fish/default.nix` |
| A Fish function or completion | `modules/fish/functions/` or `modules/fish/completions/`; see [Fish](fish.md) |
| A macOS default | `hosts/m5-mbp/defaults.nix` |
| A custom package | `packages/<name>/default.nix`, called from a tier file or module |
| An operational script | `scripts/`, with a `~/.local/bin` shim in `modules/nix-ops-tools/default.nix` ([ADR-012](../decisions/012-script-exposure-via-local-bin-shims.md)) |
| A new machine | [Hosts](hosts.md) |

[`CODING_STANDARDS.md`](../../CODING_STANDARDS.md) has the judgment rules for these changes, such as when a module may link a file out of the store.
