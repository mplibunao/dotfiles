# Retrospective ledger: Fish setup and claude-toolkit links in Home Manager

Request: none · Plans: `nix/plans/fish-functions-hm.md`, `nix/plans/fish-parity-implementation.md`, `nix/plans/starship-toml-migration.md`, and `nix/plans/claude-toolkit-home-manager-module.md` in `mplibunao/dotfiles-private`

Between 2025-12-25 and 2026-02-02, with one follow-up on 2026-04-27, this work moved Fish functions into this repository, brought Fish up to the legacy shell setup, moved the Starship prompt config into `nix/`, and briefly made claude-toolkit's links into `~/.claude` and `~/.codex` a Home Manager module. The plans behind it are undated.

| Item | Outcome |
|------|---------|
| 1. Fish functions in Home Manager | done |
| 2. Fish parity and the Starship config | done |
| 3. claude-toolkit links as a Home Manager module | dropped |

## 1. Fish functions in Home Manager

- Decision: [ADR-019](../../nix/docs/decisions/019-store-managed-file-mappings-by-default.md) owns how Fish files are mapped now: authored functions through one out-of-store link, completions store-managed. It superseded ADR-009, which had made functions store-managed. Source: the ADRs.
- Evidence: `feat(nix): migrate fish functions to Home Manager` (2025-12-26) moved the functions into `nix/home/mp/modules/fish/functions/`, including `clm`, `findandkill`, `secret`, the Starship transient prompt, and the `a_mp/` set with `kt` and `kdev`. `refactor(nix): migrate fish functions to out-of-store symlink` (2026-04-27) made the switch ADR-019 describes.

## 2. Fish parity and the Starship config

- Evidence: `feat(fish): add vim mode, catppuccin theme, and migrate starship.toml` (2025-12-31) turned on Fish's vi key bindings, added the Catppuccin Fish plugin, and moved the Starship config into `nix/home/mp/modules/starship.toml`, which `starship.nix` reads with `builtins.fromTOML`, so the config is still edited as plain TOML.
- Deferred: the Starship plan's visual checks after a switch (Catppuccin colors, the prompt symbol, the vi-mode indicators, and command duration) have no recorded result: not verified.

## 3. claude-toolkit links as a Home Manager module

- Decision: `feat(nix): add claude-toolkit HM module with mkOutOfStoreSymlink` (2025-12-25) replaced claude-toolkit's `setup.sh` with a module that created its 12 links: 8 under `~/.claude`, 3 under `~/.codex`, and 1 under `~/.vibe-log`. `refactor(claude-toolkit): remove HM module, revert to setup.sh` (2026-02-02) removed the module again, because direct edits to linked files such as `~/.codex/config.toml` were silently reverted on `darwin-rebuild switch`. claude-toolkit's `setup.sh` has owned those links since. Source: the commit messages and the plan's status note.
