# DEPRECATED: Tide prompt is not supported under Nix.
# Starship is the canonical prompt, managed by modules/starship/default.nix
#
# Original implementation kept below for reference only.
# This function now returns exit code 2 and does nothing.

function switch-to-tide -d "Deprecated: Tide not supported under Nix"
    if status is-interactive
        echo "Tide prompt is not supported under Nix. Starship is the canonical prompt."
        echo "See: nix/README.md and nix/AGENTS.md"
    else
        echo "switch-to-tide: deprecated (exit 2)" >&2
    end
    return 2
end

# --- ARCHIVED ORIGINAL IMPLEMENTATION ---
# function switch-to-tide --description "Switch from Starship back to Tide prompt"
#     echo "🔄 Switching from Starship to Tide..."
#
#     # Step 1: Install Tide if not already installed
#     echo "📦 Installing Tide..."
#     fisher install ilancosman/tide@v6
#
#     # Step 2: Apply our Catppuccin theme
#     echo "🎨 Applying Catppuccin theme..."
#     setup-tide-theme
#
#     # Step 3: Update config.fish (needs manual edit)
#     echo ""
#     echo "⚠️  IMPORTANT: You need to manually edit ~/Projects/personal/dotfiles/fish/config.fish"
#     echo "    Replace:"
#     echo "      # Initialize Starship prompt with transient support"
#     echo "      starship init fish | source"
#     echo "      enable_transience"
#     echo ""
#     echo "    With:"
#     echo "      # Tide prompt is auto-initialized via conf.d/_tide_init.fish"
#     echo "      # No manual initialization needed!"
#     echo ""
#     echo "Then run: exec fish"
# end
