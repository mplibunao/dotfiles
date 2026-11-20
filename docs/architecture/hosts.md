# Hosts

A host is one Mac's nix-darwin configuration: a folder in `hosts/` and a `darwinConfigurations."<hostname>"` entry in `flake.nix`. The flake has one host, `m5-mbp`, an Apple Silicon MacBook Pro. Flake commands name it as `.#m5-mbp`, and `nix-verify` and `nix-ops` take it as `--host m5-mbp` ([command ladder](command-ladder.md)).

## Adding a host

1. Copy the existing host:

   ```sh
   mkdir -p hosts/<new-hostname>
   cp hosts/m5-mbp/{configuration,defaults,homebrew}.nix hosts/<new-hostname>/
   ```

2. Edit the copies for the new machine. Keep two settings in `configuration.nix`:
   - `nixpkgs.hostPlatform` matches the machine: `aarch64-darwin` on Apple Silicon. [Cross-platform](cross-platform.md#current-scope) says what an Intel Mac would need besides `x86_64-darwin`.
   - `nix.enable = false`. Determinate Nix owns the Nix installation, and nix-darwin's `nix.*` options would conflict with it.

3. Add the host to `flake.nix`, next to `m5-mbp` and with the same `specialArgs` and `home-manager.extraSpecialArgs`:

   ```nix
   darwinConfigurations."<new-hostname>" = darwin.lib.darwinSystem {
     system = "aarch64-darwin";
     specialArgs = { inherit nixpkgs-pre2611; };
     modules = [
       ./hosts/<new-hostname>/configuration.nix
       home-manager.darwinModules.home-manager
       { home-manager.extraSpecialArgs = { inherit hunk opencode; }; }
     ];
   };
   ```

4. Stage the new folder, then follow the [command ladder](command-ladder.md) with `--host <new-hostname>`:

   ```sh
   git add hosts/<new-hostname>/ flake.nix
   nix-verify --host <new-hostname>
   ```

On a Mac that isn't set up yet, the [bootstrap skill](../../.claude/skills/bootstrap/SKILL.md) covers everything before the first build.
