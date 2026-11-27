# Retrospective ledger: Gemini CLI removal

Request: none · Plan: `docs/exec-plans/completed/remove-gemini-cli-2026-08-28.md` in `mplibunao/dotfiles-private`

This work, planned and committed on 2026-08-28 and merged on 2026-08-29, removed Gemini CLI from the Nix package set and the `og` shell shortcut that launched it. Gemini's own configuration and sessions were kept.

| Item | Outcome |
|------|---------|
| 1. Remove Gemini CLI from the configuration | done |
| 2. Activation | done |
| 3. Garbage collection of old generations | not verified |

## 1. Remove Gemini CLI from the configuration

- Decision: no ADR for the removal, because [ADR-007](../../nix/docs/decisions/007-package-tiers-for-closure-management.md) already calls for pruning packages from the tiers. Source: the plan.
- Decision: leave Gemini's state alone: `~/.gemini`, including the `settings.json` link that claude-toolkit's `setup.sh` creates, and Gemini's sessions, caches, credentials, and logs. Agent Sessions stays installed and can still browse the kept Gemini sessions. Source: the plan.
- Evidence: `chore: remove Gemini CLI from Nix` (2026-08-28) removed the package from `nix/home/mp/packages/tier1.nix`, the `og` abbreviation from `fish.nix`, the Gemini-only comments from `llm-tools.nix`, the `og` alias from the legacy Zsh aliases, and the package from the inventory in `nix/docs/02-packages-and-tiers.md`. It merged on 2026-08-29. The plan lists build and lint checks but doesn't record their results: not verified.

## 2. Activation

- Evidence (checked 2026-11-20): the running system matches this repository's configuration, `gemini` doesn't resolve in Fish, the `og` abbreviation is gone, and `~/.gemini` still exists. When the first switch after the merge happened isn't recorded.

## 3. Garbage collection of old generations

- Deferred: old system generations can still hold the Gemini package until they are deleted and garbage-collected. The plan left that to a separate approval, and nothing records a result: not verified.
