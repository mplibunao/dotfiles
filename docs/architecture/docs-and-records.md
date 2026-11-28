# Docs and records

Where each kind of document goes, and which ones are committed. Current docs describe how the repository works now and are edited in place. Records describe what a piece of work found or decided and aren't rewritten later. Records are committed because later readers, agents included, can read the checkout's files but not git history or GitHub.

## Where things go

| Kind | Home | Edited after it's merged |
|---|---|---|
| Plan | `docs/plans/<topic>-<YYYY-MM-DD>.md` | Never committed; [Plans](#plans) says when to delete one |
| Run ledger | `docs/ledgers/<YYYY-MM-DD>[-issue-<number>]-<topic>.md`, one per orchestrated run | Only to finish the run that wrote it |
| Retrospective ledger | `docs/ledgers/<YYYY-MM-DD>-<topic>-retrospective.md` | No |
| Architecture decision record (ADR) | `docs/decisions/NNN-<slug>.md` | No. The decision text stays as merged, and a later ADR supersedes it. [The decisions index](../decisions/README.md#format) covers the status marker and index row |
| Investigation | `docs/investigations/<YYYY-MM-DD>-<topic>.md` | No |
| Current docs | `docs/architecture/`, and the root `AGENTS.md`, `README.md`, `CODING_STANDARDS.md`, and `GLOSSARY.md` | Yes, in place |
| Open work | Local plans, or GitHub issues on this repository | |

## Plans

A plan changes while the work runs, so a committed plan either drifts from what happened or stops showing what was approved. Plans live in `docs/plans/` and are never committed.

The folder isn't listed in `.gitignore`, `.repo_ignore`, or `.cursorignore`. RepoPrompt honors those files, so an ignored plan would drop out of its search and file selection. The [`pre-commit` hook](#hooks) keeps plans out of commits instead.

Delete a plan only after I've said the work is done, and only once its decisions are in a ledger or an ADR.

## Run ledgers

An orchestrated run writes one ledger and commits it in the run's pull request. The template for its contents (the heading, work-item table, outcomes, per-item fields, and parked decisions) is "The run ledger" section of the `rp-orchestrate-loop` skill in my private claude-toolkit repository, at `.claude/skills/rp-orchestrate-loop/SKILL.md`. Write the ledger from that template.

The date in the file name is the day the run started. Add an issue number only for an issue on this repository. In the work-item table's Agent session column, name each agent by its role and session name, such as `pair · Orchestrate 1/5`. Session IDs, transcripts, and raw tool output stay out of the ledger.

## Retrospective ledgers

A retrospective ledger records work that finished before this repository committed ledgers. It is rebuilt from the plan and the git history, and it uses the run ledger's sections without the agent session and commit columns. The date in its file name is the day it was written, and its opening says when the original work happened.

It records only what the evidence shows. A file in the tree proves the current configuration, not when it was delivered or whether it was activated with `darwin-rebuild switch`. Where the evidence stops, the ledger says "not verified."

The retrospectives dated 2026-11-20 were rebuilt from `mplibunao/dotfiles-private`, the private repository this one replaced. The investigations dated before 2026-11-20 come from it too, and the commit hashes they cite belong to its history, not this repository's.

## ADRs

A decision gets an ADR when it is hard to reverse, would surprise someone without the background, and involved a real trade-off. Other decisions stay in the ledger of the run that made them. ADRs are numbered, start from `docs/decisions/template.md`, and are listed in [the decisions index](../decisions/README.md). To replace a decision, write a new ADR and mark the old one superseded, as the index describes.

## Investigations

An investigation report states one kind of finding: a root cause, a ruled-out option, a measurement, or the evidence behind a decision. Its date is the day of what it observed, and it records what was true then. Where it disagrees with a current doc, the current doc is right. When an investigation finds a lasting rule or procedure, write that into the doc that covers the topic.

## Working files

These exist only in the local checkout and are never committed:

- plans, in `docs/plans/`;
- `prompt-exports/` and other raw RepoPrompt output;
- `docs/reviews/`, `docs/designs/`, `docs/analysis/`, and `docs/references/`;
- transcripts and logs.

To keep something a working file found, write it into a record or into the current doc that covers the topic.

## Visibility

This repository is public. Keep credentials, private Nix store paths, agent session IDs, and transcripts out of every committed file. Link with repository-relative paths, and when citing a record, give its path and the date of its evidence.

## Hooks

`.githooks/` contains two hooks. Enable them once per clone; linked worktrees share the setting:

```sh
git config core.hooksPath .githooks
```

- `pre-commit` reads the whole index and fails when any entry is `docs/plans` or sits under `docs/plans/`, compared without regard to letter case, however the entry was added. It prints the paths, and `git rm -r --cached -- <path>` removes them from the index while keeping the files. Committing the removal passes, and untracked plans never block a commit.
- `pre-push` runs `gitleaks git --redact` over the commits a push sends, including what each merge commit changes against its first parent, and blocks the push on any finding. For a new branch, or a remote branch tip this clone hasn't fetched, it scans everything reachable from the pushed commit. It also blocks when gitleaks isn't installed (the tier 2 package set provides it), when a pushed ref doesn't point at a commit, or when it can't parse the ref list Git passes it. It doesn't scan annotated tag messages.

`--no-verify` and edits made on GitHub skip both hooks. The [secret scan in CI](cross-platform.md#continuous-integration) checks pull requests and `main`, but only after the push. Merges, rebases, and cherry-picks don't run `pre-commit` either. A plan that arrives that way fails the next ordinary commit until it is removed from the index.
