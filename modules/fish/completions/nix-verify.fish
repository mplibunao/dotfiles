# Fish completions for nix-verify

# Disable file completions by default
complete -c nix-verify -f

# Options
complete -c nix-verify -l to -d "Run ladder up to level N (0-3)" -xa "0 1 2 3"
complete -c nix-verify -l level -d "Run exactly level N (0-3)" -xa "0 1 2 3"
complete -c nix-verify -l host -d "Hostname for flake target" -xa "(hostname -s)"
complete -c nix-verify -l nix-root -d "Override nix flake root" -r -F
complete -c nix-verify -l print-only -d "Print commands without running"
complete -c nix-verify -l no-all-systems -d "Omit --all-systems for level 0"
complete -c nix-verify -l allow-untracked -d "Allow untracked Nix sources"
complete -c nix-verify -s h -l help -d "Show help"
