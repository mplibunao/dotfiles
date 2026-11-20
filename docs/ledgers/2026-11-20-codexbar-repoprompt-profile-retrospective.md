# Retrospective ledger: CodexBar profile for RepoPrompt's Codex sessions

Request: none · Plan: `docs/plans/codexbar-repoprompt-stats-configuration-2026-08-21.md` in `mplibunao/dotfiles-private`

CodexBar is a menu-bar app that shows Codex usage and statistics read from Codex's session files. RepoPrompt CE runs Codex with its own Codex home, so those sessions were missing from CodexBar. This work, planned on 2026-08-21 and merged on 2026-08-26 with a path fix merged on 2026-08-27, registered RepoPrompt's Codex home as a second CodexBar profile.

| Item | Outcome |
|------|---------|
| 1. Register RepoPrompt's Codex home from Home Manager | done |
| 2. Select the RepoPrompt profile in CodexBar | done |
| 3. Statistics that come from RepoPrompt's SQLite data | dropped |

## 1. Register RepoPrompt's Codex home from Home Manager

- Decision: this repository manages one value, RepoPrompt CE's Codex home in the Codex provider's `codexProfileHomePaths` array. CodexBar keeps the rest of its writable config, including accounts, credentials, and preferences, and a helper merges that one value in at activation. [ADR-022](../decisions/022-codexbar-profile-home-merge-boundary.md) defines the boundary and the merge rules. Source: the plan.
- Evidence: `feat: add CodexBar profile reconciliation helper` and `feat: reconcile CodexBar RepoPrompt profile` (both 2026-08-21) added `nix/scripts/codexbar-config`, its fixture test `nix/tests/codexbar-config-test.sh`, and the Home Manager module `codexbar.nix`. `fix: update CodexBar XDG config path` (merged 2026-08-27) moved the target to `~/.config/codexbar/config.json`, CodexBar's XDG path.
- Evidence: the fixture test runs the helper against synthetic config and fake `launchctl`, process, and `brew` commands. Its scenarios cover idempotent reconciliation, duplicate entries and removal, malformed config, a higher-precedence config that shadows the target, exact file modes, locking, a running CodexBar, concurrent changes and races, backups, and rollback after a signal. CI runs it.
- Evidence (checked 2026-11-20): the running system matches this repository's configuration, and the Codex provider in `~/.config/codexbar/config.json` lists RepoPrompt CE's Codex home.

## 2. Select the RepoPrompt profile in CodexBar

- Decision: the merge never changes the selected Codex source, which the plan recorded as the combined OAuth and OpenAI web source. Selecting the RepoPrompt profile is a choice made in CodexBar and stays CodexBar's local state. Local session cost estimates stay off, because turning them on uses every Codex session on this Mac instead of the selected profile's. Source: the plan.
- Evidence (recorded in the plan, 2026-08-26): CodexBar 0.54.0 could keep showing the previous profile's statistics after a profile switch, and 0.54.1 fixed that upstream ([steipete/CodexBar#3132](https://github.com/steipete/CodexBar/pull/3132)). A 60 fps screen recording of 0.54.1 showed that selecting the RepoPrompt profile cleared the system profile's usage block and settled on "No usage yet." The popup's Refresh action then filled in RepoPrompt's own chart and history.
- Decision: selecting a profile doesn't guarantee a local token scan, so a newly selected profile with no snapshot needs Refresh. Source: the plan and ADR-022.

## 3. Statistics that come from RepoPrompt's SQLite data

- Decision: RepoPrompt CE keeps Codex's SQLite state in a sibling directory (`CODEX_SQLITE_HOME`) that CodexBar's profile mapping doesn't cover. Only statistics derived from the session files improve. SQLite-derived fields such as Fast and Priority attribution remain incomplete for the RepoPrompt profile. That limitation was accepted rather than worked around. Source: the plan and ADR-022.
