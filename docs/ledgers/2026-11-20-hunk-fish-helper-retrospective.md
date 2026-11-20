# Retrospective ledger: Hunk diff review from Fish

Request: none · Plan: `exec-plans/completed/hunk-fish-accessibility-2026-05-15.md` in `mplibunao/dotfiles-private`

Hunk is a terminal diff viewer. On 2026-05-15 this work added the `hd` Fish helper, which runs `hunk diff`, along with focused completions for it and Hunk defaults set from Home Manager. It merged the same day with the rest of the Hunk review tooling.

| Item | Outcome |
|------|---------|
| 1. `hd` Fish helper | done |
| 2. `hd` completions | done |
| 3. Hunk defaults from Home Manager | partial |

## 1. `hd` Fish helper

- Decision: `hd` passes its arguments to `hunk diff` unchanged, except that a leading `staged` becomes `--staged`. Hunk interprets branches, refs, and ranges, so `hd` doesn't rewrite them. Source: the plan.
- Decision: `hd` stays a Fish function, checked with a mocked `hunk` while it was written rather than with a permanent test suite. It moves to `~/.local/bin` only if it needs to work in other shells or grows real parsing. Source: the plan.
- Evidence: `feat: add hunk fish helper` and `refactor: simplify hd passthrough api` (2026-05-15). The plan records passing checks with a mocked `hunk` for `hd main`, `main..HEAD`, `main...HEAD`, `HEAD~1`, `staged --watch`, two file paths, `-- src/ui`, `main -- src/ui`, `--no-wrap`, an argument containing spaces, and the help variants.

## 2. `hd` completions

- Decision: complete `hd`'s own arguments, local branches, and paths only. Full `hunk` completions are a larger upstream surface that would drift. Source: the plan.
- Evidence: the plan records passing completion checks for the empty `hd ` menu, local branches without remote-only entries, partial branch and file names, paths after a target and after `--`, and the `--mode` and `--theme` values, plus Fish syntax checks on the function and completion files.

## 3. Hunk defaults from Home Manager

- Decision: `wrap_lines = true`, against Hunk's upstream default of `false`. The theme is a preference set in `programs.hunk.settings`, and checks don't assert a theme. Source: the plan.
- Evidence: `hunk config` (2026-05-15). The plan records that `nix-verify --host m5-mbp --to 2` passed and that the generated config contained `wrap_lines = true`.
- Evidence (checked 2026-11-20): `~/.config/hunk/config.toml` has `wrap_lines = true` and `watch = false`.
- Deferred: the plan's one remaining check, opening `hunk diff main...HEAD` after activation to see word wrap, has no recorded result: not verified. Later Hunk work, recorded in [the startup regression investigation](../investigations/2026-07-13-hunk-hd-startup-regression.md) and [its follow-up](../investigations/2026-07-26-hunk-issue-534-follow-up.md), ran with wrapping enabled and read Kitty's screen text rather than checking the rendering visually. After those, `fix: pin hunk wrapped-diff fix` (2026-07-27) moved Hunk to a fork branch with a fix for wrapped large diffs, and the `--theme` completions now list the current theme names.
