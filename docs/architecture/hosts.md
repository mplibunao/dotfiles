# Hosts

A host is one Mac's nix-darwin configuration: a folder in `hosts/` and a `darwinConfigurations."<hostname>"` entry in `flake.nix`. The flake has one host, `m5-mbp`, an Apple Silicon MacBook Pro. Flake commands name it as `.#m5-mbp`, and `nix-verify` and `nix-ops` take it as `--host m5-mbp` ([command ladder](command-ladder.md)).

## Adding a host

### Declare and stage the host

1. Copy the existing host:

   ```sh
   mkdir -p hosts/<new-hostname>
   cp hosts/m5-mbp/{configuration,defaults,homebrew}.nix hosts/<new-hostname>/
   ```

2. Edit the copies for the new machine. Keep two settings in `configuration.nix`:
   - `nixpkgs.hostPlatform` matches the machine: `aarch64-darwin` on Apple Silicon. [Cross-platform](cross-platform.md#current-scope) says what an Intel Mac would need besides `x86_64-darwin`.
   - `nix.enable = false`. Determinate Nix owns the Nix installation, and nix-darwin's `nix.*` options would conflict with it.

3. Copy the `darwinConfigurations."m5-mbp"` entry in [`flake.nix`](../../flake.nix) next to the original. In the copy, change the attribute name to `<new-hostname>` and the module path to `./hosts/<new-hostname>/configuration.nix`, and set `system` to the same value as `nixpkgs.hostPlatform`. Keep the `specialArgs` and `home-manager.extraSpecialArgs` as they are.

4. Stage the new folder:

   ```sh
   git add hosts/<new-hostname>/ flake.nix
   ```

### Check and apply the host

When nix-darwin is already installed (`darwin-rebuild` is on the `PATH`), follow the [command ladder](command-ladder.md), substituting `<new-hostname>` for `m5-mbp` wherever a command contains it. That covers the `nix-verify` examples, the evaluation, build, and dry-run commands, and the [level 4 apply](command-ladder.md#level-4-apply) command, which still needs approval.

On a Mac without nix-darwin, `darwin-rebuild` doesn't exist yet, so the ladder's build, dry-run, and apply commands can't run as written. [Phase 5 of the bootstrap runbook](../../.claude/skills/bootstrap/references/bootstrap-runbook.md#phase-5-bootstrap-flake) has the first build and switch, which run through `nix run`, with the new host name in place of `m5-mbp`. The [bootstrap skill](../../.claude/skills/bootstrap/SKILL.md) covers everything before it.
