# Command ladder

How to check a change before it reaches the live system. Every change follows the same order: edit the Nix files, evaluate, build, and then propose the apply step. Stop at the build unless I approve the apply. [`AGENTS.md`](../../AGENTS.md) states that approval rule and the rule to stage new files first.

Run the commands from the repository root. `nix-verify` runs levels 0 to 2 by default, or up to level 3 with `--to 3`, and it never runs level 4. It takes the host from `hostname -s` unless given `--host`, and this Mac's own host name isn't `m5-mbp`, so pass it explicitly. `nix-ops` has the same default.

```sh
nix-verify --host m5-mbp               # levels 0-2
nix-verify --host m5-mbp --to 3        # adds the dry-run, without sudo
nix-verify --host m5-mbp --print-only  # prints the commands without running them
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
git ls-files -z '*.nix' | xargs -0 nixfmt   # rewrites files in place
statix check .                              # antipatterns
deadnix .                                   # unused bindings
```

`nix-verify` formats only tracked `.nix` files, because the checkout can hold ignored local files that `nixfmt` must not rewrite.

## Level 2: build

```sh
darwin-rebuild build --flake .#m5-mbp
```

Builds the whole system closure and leaves a `result` link in the repository root. The live system doesn't change.

## Level 3: dry-run

```sh
sudo darwin-rebuild switch --dry-run --flake .#m5-mbp
```

Shows what activation would do without applying it. On this Mac the dry-run needs `sudo`, so I run this command in my own terminal. An agent gives me the command and doesn't run it. `nix-verify --host m5-mbp --to 3` runs the same dry-run without `sudo`, so it's the non-elevated runner and doesn't supply the `sudo` this Mac needs.

## Level 4: apply

```sh
sudo darwin-rebuild switch --flake .#m5-mbp
```

Activates the new configuration. It needs my approval and an interactive `sudo` prompt, so an agent hands me this command once the checks below pass. [Operations](operations.md) covers updates and rollback.

## Before proposing the apply

- Every new file is staged with `git add`.
- `nix flake check --no-build --all-systems` passes.
- `darwin-rebuild build` succeeds. Home Manager checks for files in the way only during activation, so a clean build doesn't rule out a collision ([Troubleshooting](troubleshooting.md#file-is-in-the-way)).
- The commit message describes the change.

## Quick reference

| Action | Command | Changes the live system |
|---|---|---|
| Evaluate | `nix flake check --no-build --all-systems` and `nix eval --raw .#darwinConfigurations.m5-mbp.system.drvPath` | No |
| Format | `git ls-files -z '*.nix' \| xargs -0 nixfmt` | No (rewrites files) |
| Lint | `statix check .` | No |
| Dead code | `deadnix .` | No |
| Build | `darwin-rebuild build --flake .#m5-mbp` | No |
| Dry-run | `sudo darwin-rebuild switch --dry-run --flake .#m5-mbp` | No; I run it |
| Apply | `sudo darwin-rebuild switch --flake .#m5-mbp` | Yes; needs my approval |
