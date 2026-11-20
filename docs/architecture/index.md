# Architecture docs

How the configuration works now. These docs are edited in place when the configuration changes ([Docs and records](docs-and-records.md)). The root [`AGENTS.md`](../../AGENTS.md) routes agents here.

## Making a change

- [Command ladder](command-ladder.md): the checks from evaluation to an approved switch.
- [Repository layout](repository-layout.md): what each folder holds and where a change goes.
- [Hosts](hosts.md): the one host, and how to add another.
- [`CODING_STANDARDS.md`](../../CODING_STANDARDS.md): judgment rules for changes.
- [`GLOSSARY.md`](../../GLOSSARY.md): Nix terms as this repository uses them.

## How the system fits together

- [Overview](overview.md): Determinate Nix, nix-darwin, and Home Manager, and what stays outside Nix.
- [Packages and tiers](packages-and-tiers.md): the tier lists and how to add or remove a package.
- [Dotfiles mapping](dotfiles-mapping.md): how files reach the home directory, and which stay manual.
- [GUI apps](gui-apps.md): Homebrew casks, the allowed brews, apps installed by hand, and login items.
- [Cross-platform](cross-platform.md): what runs where, and what CI checks on Linux.

## Running it

- [Operations](operations.md): updating inputs, applying, rolling back, and the `nix-ops` commands.
- [Storage](storage.md): store size, garbage collection, and keeping the closure small.
- [Troubleshooting](troubleshooting.md): evaluation, build, activation, and shell errors.

## Tools

- [AeroSpace](aerospace.md): configuration files, stopping it for games, and the layout manager.
- [Fish](fish.md): functions, completions, the cheat sheet, and the `clm` launch log.
- [Keybindings](keybindings.md): where each tool's bindings live, and checking a new one for conflicts.
- [Kitty](kitty.md): close protection, remote control, and the Developer Tools permission.
- [TinyCast](tinycast.md): the launcher and its version-controlled settings.

## Runbooks

- [CLIProxyAPI and the usage dashboard](runbooks/cli-proxy-api.md)
- [Cloudflared named tunnel](../../modules/cloudflared/README.md): the procedure is in the module's folder.
- [CodexBar profile home](runbooks/codexbar.md)
- [OpenCode in RepoPrompt CE](runbooks/opencode-repoprompt.md)
- [Phone Harness](runbooks/phone-harness.md)
- [Surf CLI](runbooks/surf-cli.md)

## Records

- [Docs and records](docs-and-records.md): where plans, ledgers, ADRs, and investigations go.
- [Decisions](../decisions/README.md): the ADR index.
