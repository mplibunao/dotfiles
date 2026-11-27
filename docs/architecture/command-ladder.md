# Command ladder

How to check a change before it reaches the live system. Every change follows the same order: edit the Nix files, evaluate, build and compare the build with the live system, and then propose the apply step. Stop at the build unless I approve the dry-run (level 3) or the switch (level 4). [`AGENTS.md`](../../AGENTS.md) states how I approve a switch, the rule to switch a change from its branch before the merge, and the rule to stage new files first.

Run the commands from the repository root. `nix-verify` runs levels 0 to 2 by default, and it never runs level 4. Its `--to 3` option runs the level 3 dry-run without `sudo`, which nix-darwin refuses, so don't run `nix-verify` past level 2. It takes the host from `hostname -s` unless given `--host`, and this Mac's own host name isn't `m5-mbp`, so pass it explicitly. `nix-ops` has the same default. `--nix-root "$PWD"` makes `nix-verify` use the checkout you are in. [Level 1](#level-1-format-and-lint) explains how it picks a root without that flag.

```sh
nix-verify --host m5-mbp --nix-root "$PWD"               # levels 0-2
nix-verify --host m5-mbp --nix-root "$PWD" --print-only  # prints the commands without running them
```

## Level 0: evaluate

```sh
nix flake check --no-build --all-systems
nix eval --raw .#darwinConfigurations.m5-mbp.system.drvPath
```

The first command checks the flake's standard outputs without building anything. It doesn't evaluate `darwinConfigurations`, so the second command evaluates the host itself, which catches syntax errors, missing imports, and type mismatches in the modules. CI runs both. `nix-verify` runs only the first at level 0; its level 2 build evaluates the host too.

## Level 1: format and lint

`statix` and `deadnix` come from [`modules/nix-ops-tools/default.nix`](../../modules/nix-ops-tools/default.nix) and `nixfmt` from [`modules/neovim/default.nix`](../../modules/neovim/default.nix), so all three are on the `PATH` in my shell. `nix-verify` still checks for each one before running it, so it also works where Home Manager isn't set up.

```sh
nix-verify --host m5-mbp --level 1 --nix-root "$PWD"
```

This is the way to format the repository. `--level 1` runs level 0 first (the flake check from [Level 0](#level-0-evaluate), without a build), then `nixfmt` on the tracked `.nix` files, `statix check .` for lint warnings, and `deadnix .` for unused bindings. `nixfmt` rewrites files in place, so read the diff after it runs. Add `--print-only` to see the commands first.

Without `--nix-root "$PWD"`, `nix-verify` works on the checkout in `$DOTFILES_DIR`, or on the live checkout `~/Projects/personal/dotfiles` when that variable is unset, even when you run it from another checkout or a worktree ([`scripts/nix-locate`](../../scripts/nix-locate)). It formats only tracked regular `.nix` files, because the checkout can hold ignored local files and symlinks that `nixfmt` must not rewrite.

## Level 2: build

```sh
darwin-rebuild build --flake .#m5-mbp
```

Builds the whole system closure and leaves a `result` link in the repository root. The live system doesn't change.

Then compare the build with the live system:

```sh
nix store diff-closures /run/current-system ./result
```

If the build removes a package the change didn't intend to remove, stop. The branch is missing work that the live system has. Merge that work into the branch before you switch.

Run the comparison in the directory where that build wrote `result`, straight after the build. `nix-verify` builds but doesn't run the comparison. The comparison shows Nix packages only. Check [`hosts/m5-mbp/homebrew.nix`](../../hosts/m5-mbp/homebrew.nix) separately, because a switch uninstalls Homebrew packages that it no longer declares. Files linked to the checkout are outside the comparison too. A first install has no live system to compare with. The `/bootstrap` command covers that case.

## Level 3: dry-run

```sh
sudo darwin-rebuild switch --dry-run --flake .#m5-mbp
```

Shows what activation would do without applying it. The dry-run needs `sudo`, because nix-darwin refuses `darwin-rebuild switch` without root, `--dry-run` included. It also needs its own approval, and a password typed for a dry-run doesn't approve a switch.

## Level 4: apply

```sh
sudo darwin-rebuild switch --flake .#m5-mbp
```

Activates the new configuration. It needs `sudo` and my approval, given in one of the two ways [`AGENTS.md`](../../AGENTS.md#rules) describes. [Operations](operations.md) covers updates and rollback.

Once the checks [before switching](#before-switching) pass, an agent whose harness has a private password prompt opens one and runs the switch itself. The prompt says which command the password is for and which commit was built, and it blocks the agent until I answer. In T3 Code the prompt is the `request_secret` tool with file delivery, and the switch runs as:

```sh
sudo -k
sudo -S -p '' darwin-rebuild switch --flake "$flake" < "$file"
```

`$flake` is the absolute flake path of the checkout that was built and compared, such as `/Users/mp/Projects/personal/dotfiles#m5-mbp`, and `$file` is the file the prompt delivered the password in. `sudo -k` drops a cached login first, so `sudo` reads the password itself and the switch doesn't receive it. The agent passes the file to `sudo` on standard input and never reads or prints it. If the harness left the file on disk, the agent deletes it after the command, whether the command succeeded or failed.

Where the harness has no private prompt, the agent waits for me to say "apply", "switch", or "go ahead and switch", then gives me the exact switch command to run.

## Switching from a branch

[`AGENTS.md`](../../AGENTS.md#rules) says which changes to switch from their branch before the merge. The steps:

1. Bring the branch up to date with `main`.
2. Build it and compare the build with the live system ([level 2](#level-2-build)).
3. Switch from the branch ([level 4](#level-4-apply)).
4. Check the behavior the change is for. If the check fails, the pull request isn't ready to merge.

Use one absolute flake path for the build and the switch, and compare the `result` that build wrote, so all three act on the same checkout. `.#m5-mbp` depends on the current directory, and `nix-verify` builds `$DOTFILES_DIR` or the live checkout unless `--nix-root` names another ([level 1](#level-1-format-and-lint)).

Home Manager links the Fish functions and `scripts/` to the live checkout ([ADR-019](../decisions/019-store-managed-file-mappings-by-default.md)). Checking out a branch there makes its versions of those files live at once, before any switch, and a rollback doesn't restore them. Ask me before you check out a branch there that changes them.

## Before switching

- Every new file is staged with `git add`.
- `nix flake check --no-build --all-systems` passes.
- `darwin-rebuild build` succeeds. Home Manager checks for files in the way only during activation, so a clean build doesn't rule out a collision ([Troubleshooting](troubleshooting.md#file-is-in-the-way)).
- `nix store diff-closures` against the live system doesn't show a package removed by accident.
- The commit message describes the change.

## Quick reference

| Action | Command | Changes the live system |
|---|---|---|
| Evaluate | `nix flake check --no-build --all-systems` and `nix eval --raw .#darwinConfigurations.m5-mbp.system.drvPath` | No |
| Format and lint | `nix-verify --host m5-mbp --level 1 --nix-root "$PWD"` (runs level 0 first) | No (rewrites files) |
| Lint | `statix check .` | No |
| Dead code | `deadnix .` | No |
| Build | `darwin-rebuild build --flake .#m5-mbp` | No |
| Compare | `nix store diff-closures /run/current-system ./result` | No |
| Dry-run | `sudo darwin-rebuild switch --dry-run --flake .#m5-mbp` | No; needs `sudo` and its own approval |
| Apply | `sudo darwin-rebuild switch --flake .#m5-mbp` | Yes; needs my approval |
