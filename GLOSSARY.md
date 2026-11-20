# Glossary

Nix terms as this repository uses them. Where agents tend to mix terms, an entry lists the synonyms to avoid, so docs and commits keep calling one thing by one name.

## Activation

Running a generation's activation script, which makes it the live system: it links files into the home directory, loads LaunchAgents, applies macOS defaults, and runs Homebrew. `darwin-rebuild switch` builds and then activates, while `darwin-rebuild build` only builds. Activation needs my approval ([`AGENTS.md`](AGENTS.md)).

_Avoid_: deploy, install

## Closure

A store path together with every store path it refers to, directly or indirectly. The system closure is everything `darwinConfigurations.m5-mbp.system` needs, and its size is what the tiers keep in check.

_Avoid_: dependency tree, install size

## Derivation

A build recipe that Nix produces by evaluating an expression: its inputs, its builder, and the store paths it will output. Building a derivation produces those outputs. A derivation's own file is its `drvPath`, and its main output is its `outPath`.

_Avoid_: build (for the recipe), package (for the recipe)

## Flake input

A source the flake pins in `flake.lock`, such as `nixpkgs`, `darwin` (nix-darwin), `home-manager`, `hunk`, or `opencode`. Updating an input changes its locked revision and hash.

_Avoid_: dependency, channel (this flake doesn't use channels)

## Generation

One numbered version of the nix-darwin system profile. Each `darwin-rebuild switch` creates one, and a rollback activates an earlier one. Home Manager runs as a nix-darwin module, so its files change with the system generation.

_Avoid_: snapshot, revision, version

## Host

One machine's nix-darwin configuration: a folder in `hosts/` and an entry in `darwinConfigurations` in `flake.nix`. `m5-mbp` is the only host ([Hosts](docs/architecture/hosts.md)).

_Avoid_: machine config, system (for the folder)

## IFD (import from derivation)

Evaluation that has to build a derivation before it can continue, such as importing a Nix file that a build produces. Darwin derivations need a macOS builder, so CI evaluates the Darwin system on Linux with IFD turned off ([Cross-platform](docs/architecture/cross-platform.md)).

## Module

A Nix file, usually `default.nix`, that sets options for nix-darwin or Home Manager. The Home Manager modules are in `modules/<tool>/`, one per tool, and the nix-darwin ones are in `hosts/m5-mbp/`.

_Avoid_: plugin, config file

## Out-of-store link

A home-directory path that Home Manager links straight to a file in this checkout with `config.lib.file.mkOutOfStoreSymlink`, so an edit takes effect without a rebuild. The default is a store-managed mapping, which links to a copy in the store ([ADR-019](docs/decisions/019-store-managed-file-mappings-by-default.md)).

_Avoid_: mutable symlink, live symlink

## Store path

A path under `/nix/store/`, named by a hash, that holds one immutable build output or copied source.

_Avoid_: Nix path, store file

## Tier

One of the package lists in `home/mp/package-tiers/`, ordered by how soon a package is needed ([Packages and tiers](docs/architecture/packages-and-tiers.md)).

_Avoid_: level (the command ladder has levels), group
