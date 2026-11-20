# Fish completions for nix-locate

# Disable file completions by default
complete -c nix-locate -f

# Options (mutually exclusive output modes)
complete -c nix-locate -l nix-root -d "Print nix flake root path (default)"
complete -c nix-locate -l dotfiles-root -d "Print dotfiles root path"
complete -c nix-locate -l json -d "Print JSON with both paths"
complete -c nix-locate -s h -l help -d "Show help"
