# Fish completions for nix-ops

# Subcommands
set -l commands status verify update-inputs generations rollback gc switch help

# Disable file completions by default
complete -c nix-ops -f

# Subcommand completions
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a status -d "Show diagnostics (safe)"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a verify -d "Run verification ladder (safe)"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a update-inputs -d "Update flake.lock"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a generations -d "List generations (safe)"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a rollback -d "Print/apply rollback"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a gc -d "Print/apply garbage collection"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a switch -d "Print switch command (never runs)"
complete -c nix-ops -n "not __fish_seen_subcommand_from $commands" -a help -d "Show help"

# Global options
complete -c nix-ops -l host -d "Hostname for flake target" -xa "(hostname -s)"
complete -c nix-ops -l nix-root -d "Override nix flake root" -r -F
complete -c nix-ops -s h -l help -d "Show help"

# update-inputs options
complete -c nix-ops -n "__fish_seen_subcommand_from update-inputs" -l yes -d "Confirm update"
complete -c nix-ops -n "__fish_seen_subcommand_from update-inputs" -l input -d "Update specific input" -xa "(cd ~/Projects/personal/dotfiles/nix 2>/dev/null && nix flake metadata --json 2>/dev/null | jq -r '.locks.nodes | keys[]' 2>/dev/null)"
complete -c nix-ops -n "__fish_seen_subcommand_from update-inputs" -l build -d "Build after update"

# rollback/gc options
complete -c nix-ops -n "__fish_seen_subcommand_from rollback gc" -l apply -d "Execute with confirmation"

# verify passes through to nix-verify, so include its options
complete -c nix-ops -n "__fish_seen_subcommand_from verify" -l to -d "Run ladder up to level N (0-3)" -xa "0 1 2 3"
complete -c nix-ops -n "__fish_seen_subcommand_from verify" -l level -d "Run exactly level N" -xa "0 1 2 3"
complete -c nix-ops -n "__fish_seen_subcommand_from verify" -l print-only -d "Print commands only"
complete -c nix-ops -n "__fish_seen_subcommand_from verify" -l allow-untracked -d "Allow untracked files"
