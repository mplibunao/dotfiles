# Skills audit 2026-11-20

## Scope

The diff `feature/nix-first-layout..feature/docs-router` for pull request #6, at head `66c00ec`. That covers the 66 Markdown files the diff adds, renames, or modifies, each read whole, and the agent-facing strings it changes in code: the activation and launch-wrapper messages in `modules/` and the output of `.claude/skills/bootstrap/scripts/`. ADR bodies, ledgers, and the investigation keep their wording as records, so they were checked for broken links and nothing else. Usage window: 2026-08-22 00:00 UTC to 2026-11-20 00:00 UTC.

## Checks run

| Check | Command or method | Result |
| --- | --- | --- |
| Structure | This repository has no skill lint. Equivalents: claude-toolkit's `verify:skills` with `TOOLKIT_ROOT` set to this checkout, and its skill lint's 180-character description cap; `shellcheck -S warning` 0.11.0 and `bash -n` on the two bootstrap scripts; `bash -n` on the two edited `scripts/` files; `fish -n` on the two edited Fish functions; `nix flake check . --no-write-lock-file --no-build --all-systems`; `nix eval --raw .#darwinConfigurations.m5-mbp.system.drvPath`; a search of `tests/` for the changed strings; a relative-link and anchor check over the 66 files | `verify:skills` reports both bootstrap scripts as code in a skill folder. That rule is claude-toolkit's packaging convention, which this repository doesn't follow, so it isn't a finding. It finds no YAML colon traps. The description is 232 characters (finding 15). `shellcheck`, `bash -n`, and `fish -n` pass, the flake check exits 0, and the host evaluates. No test pins any changed string. 414 relative links and anchors resolve; the one hit, in `docs/decisions/README.md:11`, is a placeholder inside inline code |
| Usage and dependents | `transcripts scan --skill bootstrap --exclude-read-skill-count-at-least 8`, without subagents, over the default roots; the `skillUsage` tally in `~/.claude.json` that `/skill-doctor` reports, read directly; toolkit telemetry in `usage.db`; a search of this repository and claude-toolkit for links to the skill and `/bootstrap` | 18,484 conversations (18,530 files, `complete: true`; diagnostic codes `timestamp-regression`, `unknown-wrapper`, and `unsupported-read-shape` 20 each, `unknown-record` 1). One `skill-read` in one conversation, Codex format, `codex_exec` harness through RepoPrompt CE, dated 2026-11-19, the day this pull request's edits were made. No slash invocations, Skill tool calls, or injected loads. 21 audit sessions excluded. Claude Code's tally has no `bootstrap` entry among 149 skills. Telemetry has 0 rows, and no package records under that name, so 0 means nothing was recorded. The skill runs only on a fresh Mac, so low counts are expected and no retire is proposed. Dependents: `.claude/commands/bootstrap.md`, `AGENTS.md:19`, `CODING_STANDARDS.md:37`, `README.md:9`, `:13`, `:41`, `docs/architecture/hosts.md:32`, `keybindings.md:15`, `packages-and-tiers.md:21`, `repository-layout.md:22`, and `troubleshooting.md:401`. No claude-toolkit file routes to it |
| Prose | Vale 3.26.0 with `~/.config/vale/.vale.ini` on the 32 current docs, steering files, the decisions index, and ADR-027, and on the changed code strings written to a temporary Markdown file; the `unslop` docs rules, report-only; every path, link, and command the current docs name, resolved | Vale: 397 errors, 425 warnings, 2,032 suggestions. Most errors are tool names that aren't in the spelling vocabulary (98), the `Fish` and `Dotfiles` capitalization terms (65), and contraction preferences (65); 145 come from `ai-tells` rules, led by semicolons (36) and three-item series (23). The docs speak as "I" on purpose, so the first-person warnings don't apply. The code strings draw identifier and CLI-flag hits, plus an em dash and a semicolon in the CodexBar message lines this diff didn't change. The reading pass produced findings 5, 6, 7, 10, 11, 12, 14, 16, and 22. The cross-repository paths (claude-toolkit's `setup.sh`, `mcp-configs/secrets-wrapper.md`, `rp-orchestrate-loop`'s run ledger section, the Surf tracker's TD-041) and the forced-mapping line anchors all resolve |
| Restated rules | Reading pass per `references/restated-rules.md`, with `AGENTS.md` as the owner of its three rules | The switch-approval rule appears at about fifteen commands across the docs; the OpenCode runbook states it in full five times (finding 9), and the rest are short clauses at the commands they govern (row 24). The staging rule reappears in the bootstrap runbook and in `troubleshooting.md` (row 24) |
| Platform claims | Vendor source and documentation, and `--help` of the installed tools, checked 2026-11-20 | Changed: nix-darwin refuses a non-root `switch --dry-run` (finding 1); Home Manager backs up forced targets (finding 2); `determinate-nixd status` reports FlakeHub login (finding 21); a running Fish shell reloads an edited function by itself, and `functions --erase` stops autoloading (finding 8). Hold: `nix flake check` doesn't evaluate `darwinConfigurations` (its `--help` list of checked outputs); Home Manager's backup and "would be clobbered" behavior in `troubleshooting.md` (`check-link-targets.sh` at `0992a29`); activation needs root (`darwin-rebuild.sh:149`); the Determinate installer installs Determinate Nix by default (github.com/DeterminateSystems/nix-installer) and still accepts `--determinate`; the native Claude Code installer links `~/.local/bin/claude` (code.claude.com/docs/en/setup); `man home-configuration.nix` exists; pnpm 11 links global executables into `$PNPM_HOME/bin`. Unverifiable: rows 25 and 26 |
| Rigidity | Reading pass per `references/rigidity.md` | One-scenario step: `bootstrap-check.sh`'s phase 5 string names only `m5-mbp` (part of finding 3). Overbroad fix: `chown -R` of all of `~/.config` (finding 20). The router's "Never run … switch" is a safety invariant, which the rigidity check exempts |
| Pruning | Reading pass per `references/pruning.md`; `AGENTS.md` (with `CLAUDE.md` as its symlink, read once), the bootstrap skill and command, and the docs they route to | Always loaded: the skill description (finding 15). No-op or contradictory: Best Practices (finding 13). Duplication: findings 18, 19, and 23. Relevance: findings 10 and 17, and row 27. Every line of `AGENTS.md` passes: the opening states facts an agent can't find by looking (one host, the live checkout path), and the three rules are the safety invariants ADR-027 assigns it |

## Findings

| # | Location | Check | Evidence | Disposition | Proposed change | Effect |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `docs/architecture/command-ladder.md:5`, `:7-11`, `:48`; `docs/architecture/operations.md:263` | platform claim (nix-darwin) | The ladder offers `nix-verify --to 3` as "adds the dry-run, without sudo", and `scripts/nix-verify` runs `darwin-rebuild switch --dry-run` at level 3 without `sudo`. At the locked nix-darwin `d5bd9cd`, `pkgs/nix-tools/darwin-rebuild.sh:149-152`, and in the installed binary, `darwin-rebuild` exits 1 with "system activation must now be run as root" for any non-root `switch`, before it looks at `--dry-run`. The pull request's decoy check of the `--to 3` example ran a stub `darwin-rebuild`, so it couldn't see this | correct | Drop the `--to 3` example and say that nix-darwin refuses a non-root `switch`, so an agent stops at level 2 ([details](#finding-1)). The option itself and its help text, "no sudo, no apply", live in `scripts/nix-verify:28`, `:39`; capping `--to` at 2 there is a script change, like the `--level` help mismatch the pull request leaves for later | An agent stops at `nix-verify` levels 0 to 2 and hands over the level 3 command, instead of running `--to 3` and reporting a failed dry-run. Any harness that follows `AGENTS.md` |
| 2 | `docs/architecture/dotfiles-mapping.md:61`; `docs/architecture/troubleshooting.md:193`; `.claude/skills/bootstrap/references/bootstrap-runbook.md:170` | platform claim (Home Manager) | All three say activation replaces a forced target without a backup, and the owner adds that it removes a directory. At the locked Home Manager `0992a29`, `force` only skips the collision check (`modules/files/check-link-targets.sh:17-26`). The link step, `modules/files.nix:197-218`, moves any file or directory at a target to `<target>.$HOME_MANAGER_BACKUP_EXT` before linking, with no exception for forced paths. `nix-darwin/default.nix:35` exports that variable from `backupFileExtension`, which `hosts/m5-mbp/configuration.nix:64` sets to `"backup"`. The option's own help text, `modules/lib/file-type.nix:137-140`, says "silently delete", which is what the docs follow. Read from source; no activation ran | correct | The owner describes the backup and the one thing actually unprotected, an existing `<target>.backup`; the two copies link to it ([details](#finding-2)) | Before a switch, an agent checks for an existing `<target>.backup`, the data actually at risk, instead of warning that whatever occupies the target is deleted. After one, it knows to look in `~/.config/fish/functions.backup` for `funcsave` functions. Any harness reads the two docs, and Claude Code reads the runbook through the skill |
| 3 | `.claude/skills/bootstrap/scripts/bootstrap-check.sh:203-205`; `.claude/skills/bootstrap/SKILL.md:36` | code string; rigidity | Phase 5 ends once `check_flake_build` (`:124-130`) finds a `result` link. No phase checks for `darwin-rebuild`, so after the first build the script reports phase 6, and later "Handover complete", on a Mac that never switched. The runbook's Phase 5 includes the first switch, and its Phase 7 list requires `darwin-rebuild --version`. The phase 5 string names only `.#m5-mbp`, while the runbook tells a new host to substitute its name | correct | Add a phase 5 branch for a Mac that built but never switched, say where a new host's name goes, and widen the skill's Phase Router row ([details](#finding-3)) | An agent asks the user for the first switch instead of moving on to phase 6 without nix-darwin. It no longer reports a handover that hasn't happened. Claude Code, the only harness that loads the skill |
| 4 | `modules/cli-proxy/management-key.nix:19-21` | code string | When the secrets file is missing, the message says to create it with `<key name>=replace-with-a-long-random-string`. The same `readKeyCommand` then rejects that value as "still the placeholder" (`:53`, `:67`). The runbook's Secret file section runs `cli-proxy-dashboard-setup init-secret`, then `init-client-key`, because the proxy check needs both keys. This diff changed the third line | correct | Name the two setup commands and the runbook section ([details](#finding-4)) | An agent reading a failed switch or a launch wrapper's error log runs the setup commands, instead of writing a placeholder that fails the next check. The string is in the activation script and the three launch wrappers this pull request already changes. The LaunchAgent reloads after merging stay the same three |
| 5 | `modules/codexbar/default.nix:173`, with the comments at `:15` and `:150` | code string | The reconcile failure message sends the reader to `docs/architecture/gui-apps.md` "for the recovery and removal commands". This diff moved those commands to `docs/architecture/runbooks/codexbar.md`, and `gui-apps.md` kept a CodexBar heading only because this message names that file | correct | Name the runbook ([details](#finding-5)) | The reader of a failed switch opens the runbook directly instead of following a link from `gui-apps.md`. The change is in the activation script this pull request already changes, and it reloads no LaunchAgent |
| 6 | `docs/architecture/operations.md:187-190` | prose (command) | After pinning `nixpkgs` to a commit, the doc runs `nix flake update`, which re-locks every input. `nix flake update --help` (Determinate Nix 3.15.0, Nix 2.33.0) takes input names and updates all inputs without them, and `troubleshooting.md`'s hash-mismatch section says `nix flake update` "also upgrades every other input" | correct | `nix flake update nixpkgs` ([details](#finding-6)) | Pinning nixpkgs leaves `home-manager`, `darwin`, `hunk`, `opencode`, and `nixpkgs-pre2611` at their locked revisions. Any harness |
| 7 | `docs/architecture/storage.md:221-229` | prose (command) | `/nix/var/nix/db` is `root:wheel` mode 755 and `db.sqlite` is `root:wheel` mode 644, so the repair's `mv` and the new database write fail as the user. `troubleshooting.md` sends "database disk image is malformed" here | correct | Add `sudo` to the two writes and say why ([details](#finding-7)) | An agent hands over the repair as `sudo` commands instead of running commands that fail with permission denied. Any harness |
| 8 | `docs/architecture/fish.md:12`; the comment at `modules/fish/default.nix:24-25` | platform claim (Fish) | "A shell that has already loaded a function keeps the old version until `functions --erase <name>` or a new shell." Fish's autoloading documentation (fishshell.com/docs/current/language.html#autoloading-functions, checked 2026-11-20) says running shells reload a changed function file "after a while", and the `functions` page says `--erase` prevents the function "from autoloading in the current session". Fish 4.9.3's `src/autoload.rs:246` sets 15 seconds as "the time before we'll recheck an autoloaded file". A test with the installed Fish 4.9.3, using `fish --no-config` and a throwaway function in a scratch folder, printed the old version right after an edit and the new one 17 seconds later. After `functions --erase`, the function was "Unknown command" and stayed so through another edit and another 17 seconds, until `source` loaded it | correct | Say that the shell reloads an edit by itself, that `source <file>` loads it at once, and that `functions --erase` stops autoloading. The module comment takes the same correction ([details](#finding-8)) | An agent tells the user that an edit reaches a running shell by itself, or to `source` the file, instead of suggesting `functions --erase`, which leaves the function undefined for the rest of that session. Any harness that follows `AGENTS.md` to `fish.md`, and any agent editing the Fish module |
| 9 | `docs/architecture/runbooks/opencode-repoprompt.md:9`, `:63`; `AGENTS.md:9` | restated rule | "Do not run `darwin-rebuild switch` without explicit user approval." and "An agent must not run it or claim it completed without approval." restate `AGENTS.md:9`, which says never to switch without approval and not to claim a switch was completed. The runbook states the rule five times (`:9`, `:63`, `:130`, `:230`, `:239`), and ADR-027 gives each rule one home and names a restated rule as a risk | merge | `:9` becomes a link to the rules in `AGENTS.md`, and `:63` drops the sentence. The one-clause step lines stay ([details](#finding-9)) | None: `AGENTS.md` loads at the repository root in Claude Code, through the `CLAUDE.md` symlink, and in Codex, including RepoPrompt-launched sessions of either |
| 10 | `docs/architecture/runbooks/opencode-repoprompt.md:42` | prose (dead reference); pruning (relevance) | "Commit `64de4d0` landed the `v1.18.21` input…": `git cat-file -t 64de4d0` finds no such object in this repository, and `flake.nix` pins `v2.2.5`. `docs/ledgers/2026-11-20-opencode-repoprompt-retrospective.md` records when OpenCode was added | retire | Delete the sentence ([details](#finding-10)) | An agent stops looking for a commit this repository doesn't have. No step of the procedure depends on it |
| 11 | `README.md:49-51` | prose (dead reference) | "See the bootstrap guide for a personalization checklist": neither the skill nor its runbook has one, now or on the base branch. Item 3 says to use `hostname -s` in flake commands, while `command-ladder.md:5` and `hosts.md` name the host by its `darwinConfigurations` attribute, because this Mac's own name differs | correct | Name the host attribute and drop the checklist sentence ([details](#finding-11)) | A forker, or an agent setting up a fork, uses the host attribute in `.#<host>` instead of the Mac's name, and doesn't look for a checklist that doesn't exist |
| 12 | `docs/architecture/operations.md:97-104`; `docs/architecture/storage.md:55-57` | prose (dead command) | Both show `home-manager generations`. `command -v home-manager` finds nothing: Home Manager runs as a nix-darwin module here (`flake.nix`), and `overview.md` says there is no separate `home-manager` command | retire | Delete both ([details](#finding-12)) | An agent doesn't run a command that isn't installed. The Generation entry in `GLOSSARY.md` still explains that Home Manager's files follow the system generation |
| 13 | `docs/architecture/operations.md:271-292` | pruning (no-op); restated rule | Best Practices is advice any Nix user already follows, and two items contradict the docs that own them: "Roll back immediately", while `operations.md:3` makes every rollback wait for approval, and "Run garbage collection if needed" after an update, while `storage.md:3` and `packages-and-tiers.md:139` make cleanup its own decision | retire | Delete the section ([details](#finding-13)) | An agent no longer reads a rollback or a garbage collection as a default step after an update. It loses "Note current generation number", which the Quick Reference's `darwin-rebuild --list-generations` covers |
| 14 | `.claude/skills/bootstrap/SKILL.md:54` | prose (path) | "`scripts/bootstrap-neovim.sh --help`" is relative to the skill folder. The skill's other commands (`:19-25`) and the command file (`bootstrap.md:34`) use paths from the repository root, where `scripts/` has no `bootstrap-neovim.sh` | correct | `.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --help` ([details](#finding-14)) | The command runs from the repository root, like the skill's other commands. Claude Code |
| 15 | `.claude/skills/bootstrap/SKILL.md:3` | pruning (always loaded) | The description is 232 characters, up from 215 on the base branch. claude-toolkit's skill lint caps descriptions at 180 for agent discovery (`packages/toolkit-lint/src/cli.ts:42`). Its last sentence says where the skill ends, which doesn't help a model decide to load it | trim | Drop the last sentence, leaving 161 characters ([details](#finding-15)) | The skill listing in every Claude Code session in this repository is 71 characters shorter. The triggers "new Mac", "Determinate Nix", and "first darwin-rebuild" stay, and the body still names the handover to `AGENTS.md` |
| 16 | `CODING_STANDARDS.md:35`, `:37` | prose (contradiction) | The opening sentence gives every step that can be automated "a script in `scripts/`", but the first bullet sends steps for a new Mac to the bootstrap skill, whose scripts live in `.claude/skills/bootstrap/scripts/` | correct | Drop the location from the opening sentence, and name the skill's scripts folder in the bullet ([details](#finding-16)) | An agent writing a script for a new Mac puts it beside `bootstrap-check.sh`, not in `scripts/`. Any harness that follows `AGENTS.md` |
| 17 | `docs/architecture/gui-apps.md:138-145` | pruning (relevance) | Expected Verification Records lists CodexBar and RepoPrompt CE with the status "Pending". `docs/architecture/docs-and-records.md:15` puts open work in local plans or GitHub issues on this repository, not in current docs | retire (waits for approval) | Delete the table, then either file the two verifications as a GitHub issue on this repository or drop them. Keep "Re-verify after tap updates." ([details](#finding-17)) | An agent reading GUI apps no longer takes two stale "Pending" rows for the current state. Where the record of the outstanding verifications goes, or whether it goes, is the decision that waits, and filing an issue needs approval |
| 18 | `docs/architecture/gui-apps.md:7`, `:147-154` | pruning (duplication, cache) | `onActivation.cleanup = "uninstall"` appears at `:7`, `:96`, and `:151`, and in the comment beside it at `hosts/m5-mbp/homebrew.nix:17`. The other Notes items repeat the Nix-packages table's TinyCast row or say where casks install | trim | Delete `:7` and the Notes section, and keep the note at `:96` ([details](#finding-18)) | None for any procedure. The reader loses the bare line "Prefer Nix packages when available and functional"; ADR-016, linked at `:34`, says when a formula is used instead of a Nix package |
| 19 | `.claude/commands/bootstrap.md:18-41` | pruning (duplication) | Step 1 of the command reads `SKILL.md`, which has the same status commands (`:19-25`), the same Neovim paragraph (`:52-54`), and the same references (`:44-50`) | trim | Keep the three Instructions steps ([details](#finding-19)) | None in Claude Code, the only harness that runs `/bootstrap`, because step 1 loads `SKILL.md`. `--phase`, which only the command listed, stays in `bootstrap-check.sh --help` |
| 20 | `docs/architecture/troubleshooting.md:207-211` | rigidity | The fix for a "Permission denied" on one path is `sudo chown -R $USER:staff ~/.config/`, which changes the owner of everything under `~/.config` | correct | Check and fix only the path in the error ([details](#finding-20)) | An agent proposes a `chown` limited to the failing path. Any harness |
| 21 | `docs/architecture/troubleshooting.md:334` | platform claim (Determinate Nix) | "**Status:**" labels `sudo determinate-nixd status`, which `determinate-nixd --help` (Determinate Nix 3.15.0) describes as "Display your current FlakeHub login status" | correct | Relabel it ([details](#finding-21)) | An agent doesn't read a FlakeHub login status as the health of Nix. Any harness |
| 22 | `docs/architecture/repository-layout.md:22-23` | prose (completeness) | The pull request keeps this tree because it is the only list of what the top-level folders contain, but the tree leaves out `.githooks/`, whose two hooks `docs-and-records.md` describes | correct | Add a `.githooks/` line ([details](#finding-22)) | An agent looking for the hooks from the layout doc finds them. Any harness |
| 23 | `docs/architecture/storage.md:193-209` | pruning (duplication) | Don't Install Heavy Dev Tools Globally and Don't Mix Package Managers repeat Preventing Bloat items 4 and 5 (`:126`, `:144`) in the same file, and Don't Keep Too Many Generations repeats the Target Metrics row | trim | Delete the three subsections and keep Don't Delete Store Paths Manually ([details](#finding-23)) | None: the file keeps each point once |
| 24 | `AGENTS.md:9-10`; `command-ladder.md:3`, `:56`; `aerospace.md:61`, `:79`; `operations.md:3`, `:51`; `troubleshooting.md:3`, `:401`; `gui-apps.md:94`; `runbooks/codexbar.md:23`; `runbooks/cli-proxy-api.md:72`; `bootstrap-runbook.md:156`, `:169-172`, `:340` | restated rule | The router's approval and staging rules reappear as short clauses beside the commands they govern. Most cite `AGENTS.md` or the ladder. The bootstrap runbook's copies serve a person working through the steps on a fresh Mac before any agent runs | keep | none | None. Removing the clauses would save a few words each, and the bootstrap runbook's copies are read where `AGENTS.md` may not be loaded |
| 25 | `CODING_STANDARDS.md:17` | platform claim (Fish) | "Fish shows it in tab completion when few enough functions match for it to use the list layout." fishshell.com/docs/current/interactive.html, checked 2026-11-20, covers the colors of completion descriptions but not when they appear: unverifiable | keep | none | None. The claim rests on observation, and the rule it explains stands without it |
| 26 | `docs/architecture/storage.md:84` | platform claim (Nix) | "Run without `sudo`, these remove only the generations of profiles the current user owns." The `nix-collect-garbage` manual at nix.dev/manual/nix/latest/command-ref/nix-collect-garbage, checked 2026-11-20, doesn't separate root from other users. `/nix/var/nix/profiles` and its `system` link are `root:wheel`, so a user can't remove system generations: unverifiable from documentation, consistent with the permissions | keep | none | None |
| 27 | `AGENTS.md:23` | pruning (relevance) | "Tools with their own procedures" names five runbooks. This diff adds a sixth, `runbooks/codexbar.md`, which `docs/architecture/index.md` lists and GUI apps links to. ADR-027 accepts a topic listed in either the router or the index | keep | none | None. CodexBar's runbook is two links from the router |

## Finding details

### Finding 1

`docs/architecture/command-ladder.md:5`, `:7-11`, `:48`, and `docs/architecture/operations.md:263`. The `--to 3` sentences and example are new in this diff. The base ladder, `nix/AGENTS.md:186` at `feature/nix-first-layout`, showed the level 3 command as `darwin-rebuild switch --dry-run --flake .#m5-mbp`, also without `sudo`.

**command-ladder.md:5**

Current, 457 characters:

````text
Run the commands from the repository root. `nix-verify` runs levels 0 to 2 by default, or up to level 3 with `--to 3`, and it never runs level 4. It takes the host from `hostname -s` unless given `--host`, and this Mac's own host name isn't `m5-mbp`, so pass it explicitly. `nix-ops` has the same default. `--nix-root "$PWD"` makes `nix-verify` use the checkout you are in. [Level 1](#level-1-format-and-lint) explains how it picks a root without that flag.
````

Revised, 532 characters (+75):

````text
Run the commands from the repository root. `nix-verify` runs levels 0 to 2 by default, and it never runs level 4. Its `--to 3` option runs the level 3 dry-run without `sudo`, which nix-darwin refuses, so stop at level 2. It takes the host from `hostname -s` unless given `--host`, and this Mac's own host name isn't `m5-mbp`, so pass it explicitly. `nix-ops` has the same default. `--nix-root "$PWD"` makes `nix-verify` use the checkout you are in. [Level 1](#level-1-format-and-lint) explains how it picks a root without that flag.
````

**command-ladder.md:7-11**

Current, 269 characters:

````text
```sh
nix-verify --host m5-mbp --nix-root "$PWD"               # levels 0-2
nix-verify --host m5-mbp --nix-root "$PWD" --to 3        # adds the dry-run, without sudo
nix-verify --host m5-mbp --nix-root "$PWD" --print-only  # prints the commands without running them
```
````

Revised, 179 characters (−90):

````text
```sh
nix-verify --host m5-mbp --nix-root "$PWD"               # levels 0-2
nix-verify --host m5-mbp --nix-root "$PWD" --print-only  # prints the commands without running them
```
````

**command-ladder.md:48**

Current, 361 characters:

````text
Shows what activation would do without applying it. On this Mac the dry-run needs `sudo`, so I run this command in my own terminal. An agent gives me the command and doesn't run it. The `--to 3` example at the [top of this page](#command-ladder) runs the same dry-run without `sudo`, so it's the non-elevated runner and doesn't supply the `sudo` this Mac needs.
````

Revised, 222 characters (−139):

````text
Shows what activation would do without applying it. nix-darwin refuses `darwin-rebuild switch` without root, `--dry-run` included, so I run this command in my own terminal. An agent gives me the command and doesn't run it.
````

**operations.md:263**

Current, 168 characters:

````text
| `nix-verify` | Runs the [command ladder](command-ladder.md) up to the build; `--to 3` adds the dry-run without `sudo` ([level 3](command-ladder.md#level-3-dry-run)) |
````

Revised, 80 characters (−88):

````text
| `nix-verify` | Runs levels 0 to 2 of the [command ladder](command-ladder.md) |
````

### Finding 2

`docs/architecture/dotfiles-mapping.md:61` owns the warning. `docs/architecture/troubleshooting.md:193` and `.claude/skills/bootstrap/references/bootstrap-runbook.md:170` repeat it and become links to the owner. All three passages are new in this diff. The base had no forced-mapping warning.

**dotfiles-mapping.md:61**

Current, 548 characters:

````text
A mapping with `force = true` skips Home Manager's collision check. Activation replaces whatever is at the target without a backup, and for a directory it removes the whole directory, including files Home Manager never created. That happens on any switch, even one that doesn't touch the mapping. Before you apply, move aside anything you want to keep that occupies one of these targets instead of the intended link. For `~/.config/fish/functions`, that includes functions saved with `funcsave`. Each row links to the line that sets `force = true`:
````

Revised, 759 characters (+211):

````text
A mapping with `force = true` skips Home Manager's collision check, but activation still applies `backupFileExtension = "backup"` from `hosts/m5-mbp/configuration.nix`. A file or directory at the target moves to `<target>.backup`, and a symlink is replaced without a backup. Nothing protects an existing `<target>.backup`: a file there is overwritten, and a directory target moves inside the old backup directory. This happens on any switch where something other than Home Manager's link occupies the target, so before you apply, move aside any `<target>.backup` you want to keep. Functions saved with `funcsave` into a real `~/.config/fish/functions` directory end up in `~/.config/fish/functions.backup`. Each row links to the line that sets `force = true`:
````

**troubleshooting.md:193**

Current, 265 characters:

````text
- Mappings with `force = true` skip the collision check, and activation replaces whatever is at the path without a backup. [Forced Mappings](dotfiles-mapping.md#forced-mappings) lists the paths. Move anything you want to keep at those paths aside before the switch.
````

Revised, 186 characters (−79):

````text
- Mappings with `force = true` skip the collision check. [Forced Mappings](dotfiles-mapping.md#forced-mappings) lists the paths and says what activation does with whatever occupies them.
````

**bootstrap-runbook.md:170**

Current, 258 characters:

````text
Some mappings replace whatever is already at their path without a backup. Before the first switch, check those paths and move aside anything there worth keeping. [Forced Mappings](../../../../docs/architecture/dotfiles-mapping.md#forced-mappings) lists them.
````

Revised, 246 characters (−12):

````text
Some mappings skip Home Manager's collision check. Before the first switch, read [Forced Mappings](../../../../docs/architecture/dotfiles-mapping.md#forced-mappings), which lists them and says what activation does with whatever is at their paths.
````

### Finding 3

`.claude/skills/bootstrap/scripts/bootstrap-check.sh:203-205`, which builds the `next_step` string the script prints, and the matching row in `.claude/skills/bootstrap/SKILL.md:36`. The agent receives the phase 5 string as `Build flake: cd ~/Projects/personal/dotfiles && nix run nix-darwin#darwin-rebuild -- build --flake .#m5-mbp`. The base string at `feature/nix-first-layout` ended in `.#$(hostname -s)`.

**bootstrap-check.sh:203-205**

Before, `feature/nix-first-layout`, 171 characters:

````text
elif ! check_flake_build; then
  phase=5
  next_step="Build flake: cd ~/Projects/personal/dotfiles && nix run nix-darwin#darwin-rebuild -- build --flake .#\$(hostname -s)"
````

Current, 162 characters:

````text
elif ! check_flake_build; then
  phase=5
  next_step="Build flake: cd ~/Projects/personal/dotfiles && nix run nix-darwin#darwin-rebuild -- build --flake .#m5-mbp"
````

Revised, 384 characters (+222):

````text
elif ! check_flake_build; then
  phase=5
  next_step="Build flake (put your host's name in place of m5-mbp if you added one): cd ~/Projects/personal/dotfiles && nix run nix-darwin#darwin-rebuild -- build --flake .#m5-mbp"
elif ! check_darwin_rebuild; then
  phase=5
  next_step="First switch: after the user approves, give them the Apply command from Phase 5 of the bootstrap runbook"
````

**SKILL.md:36**

Current, 42 characters:

````text
| Nix but no build | 5 | Bootstrap flake |
````

Revised, 71 characters (+29):

````text
| Nix but no build, or built but never switched | 5 | Bootstrap flake |
````

### Finding 4

`modules/cli-proxy/management-key.nix:19-21`, the three `echo` lines of `readKeyCommand`, quoted as the reader receives them. `<secrets file>` is `cfg.secretsFile` and `<key name>` is `CLIPROXY_MANAGEMENT_KEY` or `CLIPROXY_CLIENT_KEY`. `checkCliProxyApiRuntime` (`api.nix:139`) prints it in the activation output, and the launch wrappers (`api.nix:273`, and `readCommand` at `management-key.nix:77`) write it to their error logs. Only the third line changed in this diff.

Before, `feature/nix-first-layout`, 154 characters:

````text
cli-proxy: <secrets file> is missing.
  Create it mode 0600 with <key name>=replace-with-a-long-random-string.
  Steps: nix/docs/runbooks/cli-proxy-api.md
````

Current, 163 characters:

````text
cli-proxy: <secrets file> is missing.
  Create it mode 0600 with <key name>=replace-with-a-long-random-string.
  Steps: docs/architecture/runbooks/cli-proxy-api.md
````

Revised, 177 characters (+14):

````text
cli-proxy: <secrets file> is missing.
  Run scripts/cli-proxy-dashboard-setup init-secret, then init-client-key.
  Steps: docs/architecture/runbooks/cli-proxy-api.md#secret-file
````

### Finding 5

`modules/codexbar/default.nix:173`, the last line of the reconcile failure message, as the reader receives it. The comments at `:15` and `:150` name the same file and take the same path change.

Before, `feature/nix-first-layout`, 65 characters:

````text
  See nix/docs/gui-apps.md for the recovery and removal commands.
````

Current, 74 characters:

````text
  See docs/architecture/gui-apps.md for the recovery and removal commands.
````

Revised, 83 characters (+9):

````text
  See docs/architecture/runbooks/codexbar.md for the recovery and removal commands.
````

### Finding 6

`docs/architecture/operations.md:187-190`, in Pin to Specific Revision. The text moved unchanged from `nix/docs/04-operations-update-rollback.md`.

Current, 50 characters:

````text
Then update the lock:
```bash
nix flake update
```
````

Revised, 78 characters (+28):

````text
Then update only that input's lock entry:
```bash
nix flake update nixpkgs
```
````

### Finding 7

`docs/architecture/storage.md:221-229`, under If Store Becomes Corrupted. The text moved unchanged from `nix/docs/05-storage-management.md`.

Current, 266 characters:

````text
Recovery:
```bash
# Check database
sqlite3 /nix/var/nix/db/db.sqlite "pragma integrity_check"

# If corrupted, try repair
mv /nix/var/nix/db/db.sqlite /nix/var/nix/db/db.sqlite-bkp
sqlite3 /nix/var/nix/db/db.sqlite-bkp ".dump" | sqlite3 /nix/var/nix/db/db.sqlite
```
````

Revised, 335 characters (+69):

````text
Recovery. The database is owned by root, so the repair needs `sudo`:
```bash
# Check database
sqlite3 /nix/var/nix/db/db.sqlite "pragma integrity_check"

# If corrupted, try repair
sudo mv /nix/var/nix/db/db.sqlite /nix/var/nix/db/db.sqlite-bkp
sqlite3 /nix/var/nix/db/db.sqlite-bkp ".dump" | sudo sqlite3 /nix/var/nix/db/db.sqlite
```
````

### Finding 8

`docs/architecture/fish.md:12`, with the same claim in the comment at `modules/fish/default.nix:24-25`, which this diff doesn't change. The `fish.md` line is new in this diff and restates `nix/AGENTS.md:233` at `feature/nix-first-layout`. A comment change in the module doesn't change the evaluated configuration.

**fish.md:12**

Before, `nix/AGENTS.md:233` at `feature/nix-first-layout`, 130 characters:

````text
- **Already-loaded functions in a running shell** need re-source to pick up edits: `functions --erase <name>` or open a new shell.
````

Current, 115 characters:

````text
- A shell that has already loaded a function keeps the old version until `functions --erase <name>` or a new shell.
````

Revised, 332 characters (+217):

````text
- A running shell reloads an edited function file by itself: when a call comes more than 15 seconds after fish last checked the file, fish reads it again. To load an edit at once, run `source <file>`. Don't use `functions --erase <name>` for this, because it also stops the function autoloading for the rest of that shell's session.
````

**modules/fish/default.nix:24-25**

Current, 104 characters:

````text
  #   Already-loaded functions in a running shell still need re-source:
  #     functions --erase <name>
````

Revised, 149 characters (+45):

````text
  #   A running shell reloads an edited function by itself, at the first
  #   call after fish's 15-second recheck. `source <file>` loads it at once.
````

### Finding 9

`docs/architecture/runbooks/opencode-repoprompt.md:9` and `:63`. The step lines at `:130`, `:230`, and `:239` stay: each is one clause inside an operator step.

**opencode-repoprompt.md:9**

Current, 68 characters:

````text
- Do not run `darwin-rebuild switch` without explicit user approval.
````

Revised, 79 characters (+11):

````text
- Follow the [rules in `AGENTS.md`](../../../AGENTS.md#rules) for every switch.
````

**opencode-repoprompt.md:63**

Before, `nix/docs/runbooks/opencode-repoprompt.md:71` at `feature/nix-first-layout`, the sentence the current line carries forward, 190 characters:

````text
The activation requires interactive `sudo`; an agent must not run it or claim it completed without approval. Authentication starts only after this approved activation exposes the pinned CLI.
````

Current, 455 characters:

````text
Review formatter changes, the OpenCode lock node, the built closure, and collision checks. Only after these checks, including the operator-run dry-run, pass and the user explicitly approves activation should the operator run the [level 4 apply](../command-ladder.md#level-4-apply) command from that checkout. An agent must not run it or claim it completed without approval. Authentication starts only after this approved activation exposes the pinned CLI.
````

Revised, 390 characters (−65):

````text
Review formatter changes, the OpenCode lock node, the built closure, and collision checks. Only after these checks, including the operator-run dry-run, pass and the user explicitly approves activation should the operator run the [level 4 apply](../command-ladder.md#level-4-apply) command from that checkout. Authentication starts only after this approved activation exposes the pinned CLI.
````

### Finding 10

`docs/architecture/runbooks/opencode-repoprompt.md:42`. Unchanged by this diff. The proposal deletes the sentence, because `docs/ledgers/2026-11-20-opencode-repoprompt-retrospective.md` already records when OpenCode was added.

Current, 123 characters:

````text
Commit `64de4d0` landed the `v1.18.21` input, Tier 1 package, and store-managed discovery bridge. It did not activate them.
````

Revised: deleted, 0 characters (−123).

### Finding 11

`README.md:49-51`, in For Forkers. Unchanged by this diff. The base had no personalization checklist either.

Current, 124 characters:

````text
3. **Hostname** in flake commands (run `hostname -s` to get yours)

See the bootstrap guide for a personalization checklist.
````

Revised, 209 characters (+85):

````text
3. **Host name** in flake commands: the `darwinConfigurations` name you give your host in `flake.nix`, which doesn't have to match `hostname -s` ([Hosts](docs/architecture/hosts.md#declare-and-stage-the-host))
````

### Finding 12

`docs/architecture/operations.md:97-104` and `docs/architecture/storage.md:55-57`. Both moved unchanged. The proposal deletes both, because the Generation entry in `GLOSSARY.md` already says Home Manager's files change with the system generation.

**operations.md:97-104**

Current, 203 characters:

````text
### Home Manager Generations

Home Manager also tracks generations (though when using the nix-darwin module, they're linked to system generations).

View generations:
```bash
home-manager generations
```
````

Revised: deleted, 0 characters (−203).

**storage.md:55-57**

Current, 68 characters:

````text

# Home Manager generations (if standalone)
home-manager generations
````

Revised: deleted, 0 characters (−68).

### Finding 13

`docs/architecture/operations.md:271-292`, the closing `---` and the Best Practices section, which moved unchanged and which the proposal deletes.

Current, 403 characters:

````text
---

## Best Practices

### Before Any Update

1. Ensure clean git state
2. Commit current changes
3. Note current generation number

### After Successful Update

1. Commit flake.lock
2. Test critical workflows
3. Run garbage collection if needed

### When Something Breaks

1. Roll back immediately
2. Document the issue
3. Investigate before retrying
4. Consider partial updates to isolate the problem
````

Revised: deleted, 0 characters (−403).

### Finding 14

`.claude/skills/bootstrap/SKILL.md:54`. The line is new in this diff.

Current, 411 characters:

````text
Phase 6 includes the Neovim config. The runbook has the steps: [Neovim (LazyVim config)](references/bootstrap-runbook.md#neovim-lazyvim-config) gives the recommended order and what [`bootstrap-neovim.sh`](scripts/bootstrap-neovim.sh) changes, and [Neovim validation fails](references/bootstrap-runbook.md#neovim-validation-fails) covers recovery. `scripts/bootstrap-neovim.sh --help` lists the script's options.
````

Revised, 436 characters (+25):

````text
Phase 6 includes the Neovim config. The runbook has the steps: [Neovim (LazyVim config)](references/bootstrap-runbook.md#neovim-lazyvim-config) gives the recommended order and what [`bootstrap-neovim.sh`](scripts/bootstrap-neovim.sh) changes, and [Neovim validation fails](references/bootstrap-runbook.md#neovim-validation-fails) covers recovery. `.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --help` lists the script's options.
````

### Finding 15

`.claude/skills/bootstrap/SKILL.md:3`, the `description` value.

Before, `feature/nix-first-layout`, 215 characters:

````text
Bootstrap a fresh Mac with this dotfiles repo's Nix configuration. Use when setting up a new Mac, installing Determinate Nix, or getting to first darwin-rebuild. Covers pre-agent steps through handover to nix skill.
````

Current, 232 characters:

````text
Bootstrap a fresh Mac with this dotfiles repo's Nix configuration. Use when setting up a new Mac, installing Determinate Nix, or getting to first darwin-rebuild. Covers pre-agent steps through handover to the repository's AGENTS.md.
````

Revised, 161 characters (−71):

````text
Bootstrap a fresh Mac with this dotfiles repo's Nix configuration. Use when setting up a new Mac, installing Determinate Nix, or getting to first darwin-rebuild.
````

### Finding 16

`CODING_STANDARDS.md:35` and `:37`. The file is new in this diff. Its predecessor, Rule 4 in `nix/AGENTS.md` at `feature/nix-first-layout`, had the same split: "1. A **script** in `nix/scripts/` (for automation)" beside "Steps for a new Mac" sent to the bootstrap skill. Line 38 stays as the PR decided it.

**CODING_STANDARDS.md:35**

Current, 339 characters:

````text
Every step Nix can't express gets a script in `scripts/` when it can be automated, a written procedure when a person has to do it, or both, so nothing the system depends on is left undocumented. Examples are installing the Xcode Command Line Tools, creating an SSH key and adding it to GitHub, App Store apps, and one-time data migrations.
````

Revised, 325 characters (−14):

````text
Every step Nix can't express gets a script when it can be automated, a written procedure when a person has to do it, or both, so nothing the system depends on is left undocumented. Examples are installing the Xcode Command Line Tools, creating an SSH key and adding it to GitHub, App Store apps, and one-time data migrations.
````

**CODING_STANDARDS.md:37**

Current, 85 characters:

````text
- Steps for a new Mac go in the [bootstrap skill](.claude/skills/bootstrap/SKILL.md).
````

Revised, 142 characters (+57):

````text
- Steps for a new Mac go in the [bootstrap skill](.claude/skills/bootstrap/SKILL.md), with its scripts in `.claude/skills/bootstrap/scripts/`.
````

### Finding 17

`docs/architecture/gui-apps.md:138-145`, Expected Verification Records. Moved unchanged from `nix/docs/gui-apps.md`. The proposal deletes the subsection and keeps its last sentence under Supply-Chain Verification, after the tap-commit commands.

Current, 290 characters:

````text
### Expected Verification Records

| Item | Type | Verification | Status |
|------|------|--------------|--------|
| CodexBar | cask | TeamIdentifier | Pending |
| RepoPrompt CE | cask | `/Applications/RepoPrompt CE.app` TeamIdentifier + Gatekeeper | Pending |

Re-verify after tap updates.
````

Revised, 28 characters (−262):

````text
Re-verify after tap updates.
````

### Finding 18

`docs/architecture/gui-apps.md:7` and `:147-154`. Moved unchanged. The note at `:96` stays, because it is the one copy that changes what a reader does before adding an app.

**gui-apps.md:7**

Current, 113 characters:

````text
**Cleanup:** `onActivation.cleanup = "uninstall"` (changed from `"zap"` per ADR-016 to protect stateful app data)
````

Revised: deleted, 0 characters (−113).

**gui-apps.md:147-154**

Current, 302 characters:

````text
---

## Notes

- `onActivation.cleanup = "uninstall"` removes undeclared brews and casks (preserves cask app data; see ADR-016)
- Prefer Nix packages when available and functional
- GUI apps via Homebrew are installed to `/Applications/`
- TinyCast uses a local Nix package for the signed upstream app.
````

Revised: deleted, 0 characters (−302).

### Finding 19

`.claude/commands/bootstrap.md:19-41`: Quick Reference, Neovim, and References. This diff rewrote the Neovim and References sections and left Quick Reference unchanged. The proposal deletes all three. The three Instructions steps remain, and the first of them reads `SKILL.md`.

Current, 961 characters:

````text

## Quick Reference

```bash
# Check current phase (human-readable)
.claude/skills/bootstrap/scripts/bootstrap-check.sh

# Check current phase (JSON for scripting)
.claude/skills/bootstrap/scripts/bootstrap-check.sh --json

# Get just the phase number
.claude/skills/bootstrap/scripts/bootstrap-check.sh --phase
```

## Neovim

Phase 6 includes the Neovim config. Follow [Neovim (LazyVim config)](../skills/bootstrap/references/bootstrap-runbook.md#neovim-lazyvim-config) in the runbook, and see [Neovim validation fails](../skills/bootstrap/references/bootstrap-runbook.md#neovim-validation-fails) if it breaks. `.claude/skills/bootstrap/scripts/bootstrap-neovim.sh --help` lists the script's options.

## References

- Full skill: `.claude/skills/bootstrap/SKILL.md`
- Detailed runbook: `.claude/skills/bootstrap/references/bootstrap-runbook.md`
- Agent rules and documents by topic: `AGENTS.md`
- Checks before a switch: `docs/architecture/command-ladder.md`
````

Revised: deleted, 0 characters (−961).

### Finding 20

`docs/architecture/troubleshooting.md:207-211`, under "permission denied". Moved unchanged.

Current, 99 characters:

````text
# Check ownership
ls -la ~/.config/

# Fix ownership if needed
sudo chown -R $USER:staff ~/.config/
````

Revised, 159 characters (+60):

````text
# Check ownership of the path in the error
ls -la <path from the error>

# Fix ownership of that path if needed
sudo chown -R $USER:staff <path from the error>
````

### Finding 21

`docs/architecture/troubleshooting.md:334`, the label over `sudo determinate-nixd status`. Moved unchanged.

Current, 11 characters:

````text
**Status:**
````

Revised, 26 characters (+15):

````text
**FlakeHub login status:**
````

### Finding 22

`docs/architecture/repository-layout.md:22-23`, the end of the folder tree. The file is new in this diff.

Current, 136 characters:

````text
├── .claude/                 # Claude Code commands and the bootstrap skill
└── .github/workflows/       # CI: flake evaluation on Linux
````

Revised, 223 characters (+87):

````text
├── .claude/                 # Claude Code commands and the bootstrap skill
├── .githooks/               # pre-commit and pre-push hooks (Docs and records, Hooks)
└── .github/workflows/       # CI: flake evaluation on Linux
````

### Finding 23

`docs/architecture/storage.md:193-209`, the last three subsections of What NOT to Do, which moved unchanged. The proposal deletes them and keeps Don't Delete Store Paths Manually.

Current, 393 characters:

````text
### Don't Keep Too Many Generations

Old generations pin old store paths, preventing GC.

### Don't Install Heavy Dev Tools Globally

Large toolchains (Android SDK, full texlive, etc.) should be in project devShells, not global packages.

### Don't Mix Package Managers

Avoid:
```bash
# Same tool from multiple sources
nix profile install nixpkgs#nodejs
brew install node
npm install -g n
```
````

Revised: deleted, 0 characters (−393).


## Applied

None. This audit wrote only this report. The agent that started it reviews and applies the decided edits. Finding 17 waits for approval.

## Not checked

- Behaviour evidence: this audit reviews a diff, and the check wasn't requested.
- Platform claims in text this diff moved without rewording were not checked again: the CLIProxyAPI v8.0.53 configuration keys and Claude Code fingerprint, CodexBar 0.54.1, Surf 2.22.0, TinyCast 0.11.x, Phone Harness 0.3.3, the OpenCode v2.2.5 credential commands, RepoPrompt CE's MCP tool names, the Karabiner and Kitty key-event order, and the `clm` prompt-cache sentence in `fish.md`.
- ADR bodies, ledgers, and `docs/investigations/2025-12-26-fish-functions-not-exposed.md`: their wording is settled, so only their links were checked. Their `nix/` paths resolve through ADR-027's migration map.
- `overview.md`'s Key Design Decisions and `troubleshooting.md`'s Real Issues Encountered: deferred.
- The pull request description's "Not changed here" items: not raised again. Findings 1, 2, and 8 aren't on that list.
- Finding 2 rests on reading the locked Home Manager source. No activation ran with an occupied forced target.
- Finding 7: whether the Nix daemon has to be stopped before the database is replaced.
- `nix-collect-garbage -d` without `sudo` (row 26) wasn't run.
- No review page was requested.
