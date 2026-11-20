# Retrospective ledger: AeroSpace setup and Leader Key

Request: none · Plans: `nix/plans/aerospace-wm.md`, `nix/plans/aerospace-enhancements.md`, `nix/plans/leaderkey-install.md`, and `nix/plans/leaderkey-aerospace-integration.md` in `mplibunao/dotfiles-private`

Between 2025-12-26 and 2026-01-02, this work replaced yabai and skhd with the AeroSpace tiling window manager and added the Leader Key launcher. The plans behind it are undated. The ADRs record the lasting decisions, and this ledger records what changed and when. [The AeroSpace cheat sheet](../architecture/aerospace.md) and [layout notes](../architecture/aerospace.md#layout-manager) describe the current setup.

| Item | Outcome |
|------|---------|
| 1. AeroSpace in place of yabai and skhd | done |
| 2. Navigation, workspaces, and app placement | done |
| 3. Mission Control previews | done |
| 4. Leader Key and its AeroSpace integration | done; retired on 2026-08-27 |

## 1. AeroSpace in place of yabai and skhd

- Decision: [ADR-006](../decisions/006-aerospace-instead-of-yabai.md) chose AeroSpace over yabai, [ADR-014](../decisions/014-aerospace-toml-as-canonical-authored-config.md) made `aerospace.toml` the authored config and superseded ADR-013, and [ADR-017](../decisions/017-aerospace-keepalive-false-for-gaming-mode.md) turned off launchd's keep-alive for gaming mode. Source: the ADRs.
- Evidence: `wm: add AeroSpace + use nixpkgs jankyborders` (2025-12-27) added AeroSpace and the JankyBorders window borders, which AeroSpace still starts. `refactor(aerospace): consolidate TOML as canonical config source` (2025-12-29) followed. `chore(aerospace): disable until ready to learn` turned AeroSpace off the same day, and `feat(keybinds): LeaderKey-AeroSpace integration` turned it back on, also on 2025-12-29.

## 2. Navigation, workspaces, and app placement

- Evidence: `feat(aerospace): add Dvorak home row navigation and lettered workspaces` and then `refactor(aerospace): switch navigation to vim-style hjkl` (both 2025-12-31). Navigation uses the `h`, `j`, `k` and `l` characters for muscle memory, even though Dvorak puts them on scattered keys.
- Evidence: `feat(aerospace): add app-to-workspace assignment rules` (2025-12-31) added `nix/data/workspaces.toml` and app rules that apply only while AeroSpace starts, so a window opened later can be placed by hand. Workspace roles changed several times afterwards. The current roles are in `nix/data/workspaces.toml`.

## 3. Mission Control previews

- Evidence: `fix(defaults): add expose-group-apps for Mission Control with AeroSpace` (2025-12-31). AeroSpace parks windows of inactive workspaces off screen, which made Mission Control's previews tiny. Grouping windows by application is the configured workaround, set in `nix/hosts/m5-mbp/defaults.nix`. No record shows the previews after activation: not verified.

## 4. Leader Key and its AeroSpace integration

- Evidence: `feat: add LeaderKey launcher and keybinding management system` (2025-12-26) installed Leader Key along with the keybinding inventory tool, and `feat(keybinds): LeaderKey-AeroSpace integration` (2025-12-29) exposed AeroSpace actions in Leader Key, opened by tapping CapsLock. `feat(nix): configure LeaderKey to respect Dvorak layout` followed on 2025-12-31.
- Evidence: Leader Key was retired on 2026-08-27, as [the retirement retrospective](2026-11-20-whispering-and-leader-key-retirement-retrospective.md) records. The keybinding inventory tool isn't part of this repository.
