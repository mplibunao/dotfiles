# Retrospective ledger: Whispering and Leader Key retirement

Request: none · Plan: `docs/exec-plans/completed/dictation-and-leader-key-cleanup-2026-08-26.md` in `mplibunao/dotfiles-private`

Whispering was a dictation app and Leader Key a launcher bound to a CapsLock tap. This work, planned on 2026-08-26 and merged on 2026-08-27, removed both. It kept transcription working by making the Whisper model a Nix-managed file, and it returned CapsLock to Escape when tapped and Hyper when held. The plan was marked complete on 2026-08-27.

| Item | Outcome |
|------|---------|
| 1. Whisper model as a Nix-managed file | done |
| 2. Whispering and workspace `W` removed | done |
| 3. Leader Key removed, CapsLock restored | done |
| 4. Activation | done |
| 5. Optional cleanup of retained app data | not verified |

## 1. Whisper model as a Nix-managed file

- Decision: the `ggml-large-v3-turbo.bin` model is a fixed-output derivation pinned to the upstream file, and Home Manager links it to `~/.cache/whisper/ggml-large-v3-turbo.bin`. `whisper-cpp` stays installed for the tools that use it. Source: the plan.
- Evidence: `feat: provision declarative Whisper model` (2026-08-26) added `nix/home/mp/modules/whisper-model.nix`. In claude-toolkit, `refactor: remove Whispering model discovery` (2026-08-26) stopped looking for the model in Whispering's app data.
- Evidence (checked 2026-11-20): `~/.cache/whisper/ggml-large-v3-turbo.bin` is a Home Manager link, and the running system matches this repository's configuration.
- Deferred: the plan's transcription checks after the switch have no recorded result: not verified.

## 2. Whispering and workspace `W` removed

- Decision: workspace `W` existed only for Whispering, so it goes, after the one saved AeroSpace layout that used it is backed up and rewritten. Source: the plan.
- Evidence: `feat: retire Leader Key integration` (2026-08-27) also removed the `whispering` cask, workspace `W` from `nix/data/workspaces.toml`, and its AeroSpace rules. The plan's local evidence folder, `~/.local/state/dictation-retirement/`, holds a saved-layout proof from 2026-08-26 with the rewrite applied.
- Evidence (checked 2026-11-20): `/Applications/Whispering.app` isn't installed.

## 3. Leader Key removed, CapsLock restored

- Decision: hard cutover. Remove `leaderkey.nix`, the `leader-key` cask, the Leader Key source and extractor in the keybinding tool, and the AeroSpace integration, and restore CapsLock's earlier tap-Escape, hold-Hyper rule in Karabiner. Source: the plan. [ADR-019](../../nix/docs/decisions/019-store-managed-file-mappings-by-default.md) keeps `leaderkey.nix` as a historical example with a retirement note.
- Evidence: `feat: retire Leader Key integration` and `fix: remove retired Leader Key source` (2026-08-27). The keybinding tool's tests gained checks that the retired source is gone. That tool isn't part of this repository.
- Evidence (checked 2026-11-20): `/Applications/Leader Key.app` isn't installed.

## 4. Activation

- Decision: a temporary migration script under `nix/scripts/migrations/` ran the steps Nix can't express, and it was deleted when the retirement closed. App data is kept through the switch. Deleting it needs a separate approval that lists the exact paths. Source: the plan.
- Evidence: `~/.local/state/dictation-retirement/` holds an inventory and a disk measurement from before the change (2026-08-26) and a measurement taken after the switch (2026-08-27). `chore: remove completed migration script` (2026-08-27) deleted the script.

## 5. Optional cleanup of retained app data

- Deferred: no measurement after cleanup exists, so whether Whispering's and Leader Key's app data were deleted is not verified.
