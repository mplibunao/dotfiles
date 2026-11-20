# Fish

Fish is the login shell. [`modules/fish/default.nix`](../../modules/fish/default.nix) configures it through Home Manager's `programs.fish`: abbreviations in `shellAbbrs`, plugins, vi key bindings, and the shell init.

## Functions

Functions live in [`modules/fish/functions/`](../../modules/fish/functions/), one function per file, with the file named after the function (`emm-clean.fish` defines `emm-clean`). Fish's autoloader finds a function by that file name. Functions in the `a_mp/` subfolder are on the function path too, because the shell init adds that folder.

Home Manager links the folder to `~/.config/fish/functions` out of the store ([ADR-019](../decisions/019-store-managed-file-mappings-by-default.md)), so the live shell reads this checkout:

- Adding, editing, renaming, or deleting a function file takes effect without a rebuild.
- A shell that has already loaded a function keeps the old version until `functions --erase <name>` or a new shell.
- An untracked function file works locally, through the link, but `git stash`, a fresh checkout, and other machines don't have it. Stage it with `git add`.

`CODING_STANDARDS.md` has the [`--description` rule](../../CODING_STANDARDS.md#fish-functions) for function definitions.

## Completions

Authored completions live in [`modules/fish/completions/`](../../modules/fish/completions/). Unlike functions, they're copied into the store, because that folder also receives the generated `mise.fish`. Adding or removing a completion needs `darwin-rebuild switch`.

Don't add `pnpm.fish` there. `modules/node/default.nix` generates the pnpm completions that Corepack provides, and ADR-019 records why.

## Cheat sheet

An interactive HTML reference to the abbreviations, functions, plugins, and features lives at `~/.agent/diagrams/tooling-personal/fish-shell/cheatsheet.html`, on the machine rather than in this repository. Update it whenever a change adds, renames, or removes a function or an abbreviation.

## `clm` launch log

`clm` makes a best-effort append of one JSON object to `$XDG_STATE_HOME/clm/launches.jsonl`, or `~/.local/state/clm/launches.jsonl` when `XDG_STATE_HOME` is unset. When logging succeeds, each record contains `at` (UTC), `cwd`, `configs`, and `args`. A failure to create or secure the directory, construct the JSON, or append the record is silent and never prevents Claude from launching.

Use this log to reconstruct a crashed session with the same MCP server set. Reusing the same set is expected to let Claude reuse the cached prompt prefix; a different set invalidates it. Config names are recorded in the form that replays through `clm`, so a config outside the config directory appears as its full `.json` path rather than a bare name.

`args` is recorded verbatim and may contain prompt text or other sensitive command-line values, so the directory is kept at mode `0700`, and **`clm` writes nothing unless it owns that directory**. On a shared `$XDG_STATE_HOME` where the directory belongs to another user, `chmod` can't secure it, so logging is skipped rather than publishing arguments somewhere readable. An empty log under a shared state directory is that check working.

## Checking the fzf integration

The shell uses the `patrickf1/fzf.fish` plugin, which defines `fzf_configure_bindings`. It doesn't define `fzf_key_bindings`, which comes from fzf's own upstream `key-bindings.fish`. After a switch, this confirms the plugin loaded:

```fish
fish -ic 'functions -q fzf_configure_bindings; and echo ok; or echo missing; exit'
```
