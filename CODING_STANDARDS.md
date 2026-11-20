# Coding standards

Rules for changes to this configuration that need judgment. Formatting and lint rules aren't here: `nix-verify` runs `nixfmt`, `statix`, and `deadnix` ([command ladder](docs/architecture/command-ladder.md)).

## Home Manager modules and file mappings

- Add new configuration as a Nix module, never as a symlink made by hand.
- Use a Home Manager program module (`programs.<name>`) when one exists. Map a file with `xdg.configFile` or `home.file` only for configuration that has no module. [Dotfiles mapping](docs/architecture/dotfiles-mapping.md) shows both.
- Keep mapped files store-managed by default. Use `config.lib.file.mkOutOfStoreSymlink` only when one of [ADR-019](docs/decisions/019-store-managed-file-mappings-by-default.md)'s four conditions holds: a script that's run or iterated on often, configuration an app itself rewrites, a shell helper changed several times a week, or a checkout that a tool must read as its source of truth as it changes. Say in a comment in the module which condition applies.

## Packages

Add a package to the lowest tier that fits how soon it's needed, and put a comment with its purpose on the same line. Tier 1 is for what I need to be productive at all, such as `ripgrep`, `fzf`, and `jq`; Tier 2 is for development tools, such as `terraform` and `google-cloud-sdk`. A tool that has a Home Manager program module, such as Git or Neovim, comes from its module instead. When it isn't clear a package is needed, leave it out until it is. Moving a package to a higher tier needs a reason. [Packages and tiers](docs/architecture/packages-and-tiers.md) defines the tiers and the steps for adding one.

## Fish functions

Give every function definition a `--description`. Fish shows it in tab completion when few enough functions match for it to use the list layout.

```fish
# Good
function my-func --description 'Short explanation of what it does'
    # ...
end

# Bad: missing description
function my-func
    # ...
end
```

[Fish](docs/architecture/fish.md) covers where functions live and how they load.

## Non-declarative steps

Every step Nix can't express gets a script in `scripts/` when it can be automated, a written procedure when a person has to do it, or both, so nothing the system depends on is left undocumented. Examples are installing the Xcode Command Line Tools, creating an SSH key and adding it to GitHub, App Store apps, and one-time data migrations.

- Steps for a new Mac go in the [bootstrap skill](.claude/skills/bootstrap/SKILL.md).
- Operational steps go in a script under `scripts/` and in the architecture doc or runbook for that topic.
- One-time migration steps go in the ledger of the run that performs them ([Docs and records](docs/architecture/docs-and-records.md)).
