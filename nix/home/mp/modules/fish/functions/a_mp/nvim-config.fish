function nvim-config --description 'Set or show NVIM_APPNAME configuration'
    # NVIM_APPNAME Configuration Manager
    # ===================================
    # This function manages different Neovim configurations by setting the
    # NVIM_APPNAME environment variable persistently using Fish universal variables.
    #
    # WHY THIS APPROACH?
    # ------------------
    # 1. Zero runtime overhead - Universal variables are loaded at shell startup
    # 2. Faster than abbreviations - No text expansion needed
    # 3. Faster than wrapper functions - Direct nvim call, no function overhead
    # 4. Persistent across sessions - Set once, use everywhere
    #
    # HOW IT WORKS:
    # -------------
    # Neovim looks for configs in ~/.config/$NVIM_APPNAME/ (default: ~/.config/nvim/)
    # By changing NVIM_APPNAME, we can switch between different configurations:
    #   - nvim-lazy -> ~/.config/nvim-lazy/
    #   - nvim-chad -> ~/.config/nvim-chad/
    #   - nvim-astro -> ~/.config/nvim-astro/
    #
    # USAGE:
    # ------
    # nvim-config          # Show current configuration
    # nvim-config lazy     # Set to use ~/.config/nvim-lazy/
    # nvim-config chad     # Set to use ~/.config/nvim-chad/
    # nvim-config default  # Reset to default ~/.config/nvim/
    # nvim-config reset    # Same as default
    #
    # Then just use 'v' (abbreviation) or 'nvim' directly
    #
    # MY NEOVIM CONFIGS:
    # ------------------
    # - default (~/config/nvim/) - My main config
    # - nvim-lazy - LazyVim distro
    # - nvim-chad - NvChad distro
    # - nvim-astro - AstroNvim distro
    # - nvim-kickstart - Minimal kickstart.nvim
    #
    # PERFORMANCE NOTES:
    # ------------------
    # Comments have ZERO runtime overhead in Fish. They're stripped during
    # function parsing (happens once per session when first called).
    # You can add hundreds of lines of notes here without any performance impact!
    #
    # The universal variable lookup is also essentially free - Fish loads all
    # universal variables into memory at startup, so accessing $NVIM_APPNAME
    # is just a memory lookup, no disk I/O.
    #
    # TROUBLESHOOTING:
    # ----------------
    # - If nvim still uses wrong config, check: echo $NVIM_APPNAME
    # - To see all universal variables: set -U
    # - To manually unset: set -e NVIM_APPNAME
    # - Config directories must exist in ~/.config/nvim-{name}/
    
    if test (count $argv) -eq 0
        # Show current config
        if set -q NVIM_APPNAME
            echo "Current: $NVIM_APPNAME"
        else
            echo "Using default nvim"
        end
        return
    end
    
    switch $argv[1]
        case default reset
            # Clear the variable to use default nvim config
            set -e NVIM_APPNAME
            echo "Reset to default nvim"
        case '*'
            # Set to use nvim-{name} config directory
            # The -U flag makes it universal (persistent)
            # The -x flag exports it to child processes (nvim)
            set -Ux NVIM_APPNAME "nvim-$argv[1]"
            echo "Set to: nvim-$argv[1]"
    end
end