# Dotfiles

My macOS configuration as a Nix flake: Determinate Nix, nix-darwin for the system, and Home Manager for my user, with Home Manager modules grouped by tool in `modules/<tool>/`. It builds one host, `m5-mbp`, and the live checkout is `~/Projects/personal/dotfiles`, which some modules link into directly.

This file states the rules that appear in no other document, and for every other topic it links to the document that defines it. Read that document before acting on its topic.

## Rules

- Run `darwin-rebuild switch`, `sudo darwin-rebuild switch`, or `home-manager switch`, rollbacks included, only with my approval. I approve a switch in one of two ways: I type the `sudo` password into a private password prompt that you opened for that switch, or I say "apply", "switch", or "go ahead and switch". Dismissing the prompt declines the switch. An approval covers one attempt of one build. If the switch fails, ask again before a retry. If the checkout changed after the build, build and compare again before you ask. [Level 4 of the command ladder](docs/architecture/command-ladder.md#level-4-apply) has the procedure, including what to do when your harness has no private prompt.
- Before a change that alters the built system merges, switch from its branch and check the behavior the change is for. A docs-only change doesn't need a switch. Merge any pull request only after I say that pull request is reviewed and approved. [Switching from a branch](docs/architecture/command-ladder.md#switching-from-a-branch) has the steps.
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
