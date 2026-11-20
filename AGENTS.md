# Dotfiles

My macOS configuration as a Nix flake: Determinate Nix, nix-darwin for the system, and Home Manager for my user, with one module per tool in `modules/<tool>/`. It builds one host, `m5-mbp`, and the live checkout is `~/Projects/personal/dotfiles`, which some modules link into directly.

This file states the rules that appear in no other document, and for every other topic it links to the document that defines it. Read that document before acting on its topic.

## Rules

- Never run `darwin-rebuild switch`, `sudo darwin-rebuild switch`, or `home-manager switch`, rollbacks included, unless I explicitly say to apply or switch. Activation needs an interactive `sudo` prompt, so once the [command ladder](docs/architecture/command-ladder.md) passes and I approve, give me the exact command to run, and don't claim you completed it.
- Stage every new file with `git add` before any `nix` command evaluates the flake. A flake sees only the files Git tracks. An untracked file fails evaluation with a confusing "No such file or directory" error for a store path.
- I type on a Dvorak layout. Before suggesting or adding a keybinding, read [Keybindings](docs/architecture/keybindings.md).

## Documents by topic

- **Any configuration change:** the [command ladder](docs/architecture/command-ladder.md) for checking it, [repository layout](docs/architecture/repository-layout.md) for where it goes, and [`CODING_STANDARDS.md`](CODING_STANDARDS.md) for the judgment rules. [`GLOSSARY.md`](GLOSSARY.md) defines the Nix terms.
- **Packages and apps:** [packages and tiers](docs/architecture/packages-and-tiers.md), [GUI apps](docs/architecture/gui-apps.md).
- **Configuration files and links:** [dotfiles mapping](docs/architecture/dotfiles-mapping.md), [Fish](docs/architecture/fish.md).
- **Window management and the terminal:** [AeroSpace](docs/architecture/aerospace.md), [Kitty](docs/architecture/kitty.md).
- **A new Mac or a new host:** the `/bootstrap` command and its [skill](.claude/skills/bootstrap/SKILL.md), then [Hosts](docs/architecture/hosts.md).
- **Updates, rollback, and disk space:** [operations](docs/architecture/operations.md), [storage](docs/architecture/storage.md).
- **Something broke:** [troubleshooting](docs/architecture/troubleshooting.md).
- **CI and Linux:** [cross-platform](docs/architecture/cross-platform.md).
- **Tools with their own procedures:** [CLIProxyAPI](docs/architecture/runbooks/cli-proxy-api.md), [OpenCode](docs/architecture/runbooks/opencode-repoprompt.md), [Phone Harness](docs/architecture/runbooks/phone-harness.md), [Surf](docs/architecture/runbooks/surf-cli.md), [TinyCast](docs/architecture/tinycast.md).
- **Plans, ledgers, ADRs, and investigations:** [Docs and records](docs/architecture/docs-and-records.md) says which are committed and where each goes. The [decisions index](docs/decisions/README.md) lists the ADRs.
- **Everything else:** the [architecture index](docs/architecture/index.md).
