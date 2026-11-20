# DEPRECATED: Starship is already Nix-managed.
# Prompt configuration is in nix/home/mp/modules/starship.nix
#
# Original implementation kept below for reference only.
# This function now returns exit code 2 and does nothing.

function switch-to-starship -d "Deprecated: Starship is already Nix-managed"
    if status is-interactive
        echo "Starship is already Nix-managed. No action needed."
        echo "See: nix/README.md and nix/AGENTS.md"
    else
        echo "switch-to-starship: deprecated (exit 2)" >&2
    end
    return 2
end

# --- ARCHIVED ORIGINAL IMPLEMENTATION ---
# function switch-to-starship --description "Switch from Tide back to Starship prompt"
#     echo "🔄 Switching from Tide to Starship..."
#
#     # Step 1: Remove Tide from plugins
#     echo "📦 Removing Tide plugin..."
#     fisher remove ilancosman/tide@v6
#
#     # Step 2: Update config.fish to use Starship
#     echo "📝 Re-enabling Starship in config.fish..."
#     # This will need manual edit of config.fish
#
#     # Step 3: Clean up Tide's Universal Variables (optional but recommended)
#     echo "🧹 Cleaning up Tide settings..."
#     set -e (set -U --names | string match --entire -r '^_?tide')
#
#     echo "✅ Tide removed!"
#     echo ""
#     echo "⚠️  IMPORTANT: You need to manually edit ~/Projects/personal/dotfiles/fish/config.fish"
#     echo "    Replace:"
#     echo "      # Tide prompt is auto-initialized via conf.d/_tide_init.fish"
#     echo "      # No manual initialization needed!"
#     echo ""
#     echo "    With:"
#     echo "      # Initialize Starship prompt with transient support"
#     echo "      starship init fish | source"
#     echo "      enable_transience"
#     echo ""
#     echo "Then run: exec fish"
# end
