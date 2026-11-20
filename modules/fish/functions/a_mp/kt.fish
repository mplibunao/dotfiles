function kt --description 'Kitty tab management helper'
    # Helper: build --to args for socket-only remote control
    # Uses KITTY_LISTEN_ON if available, else falls back to user-scoped socket
    # NOTE: Each arg on separate line - fish command substitution splits on newlines only
    function __kt_to
        if test -n "$KITTY_LISTEN_ON"
            printf '%s\n' "--to" "$KITTY_LISTEN_ON"
        else
            printf '%s\n' "--to" "unix:/tmp/kitty-$USER"
        end
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case name rename
            # Set the current tab's title
            if test (count $argv) -eq 0
                echo "Usage: kt name <title>"
                return 1
            end
            kitty @ (__kt_to) set-tab-title $argv

        case new
            # Create a new tab with optional layout
            set -l layout $argv[1]
            set -e argv[1]

            switch $layout
                case 4 quad
                    # Create tab with 4 splits (2x2 grid)
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
                    kitty @ (__kt_to) goto-layout grid
                    kitty @ (__kt_to) launch --location=vsplit --cwd=current
                    kitty @ (__kt_to) launch --location=hsplit --cwd=current
                    kitty @ (__kt_to) focus-window --match neighbor:left
                    kitty @ (__kt_to) launch --location=hsplit --cwd=current

                case dev
                    # Create tab with 2 columns - wide left (70%), thin right (30%) for chat/logs
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
                    kitty @ (__kt_to) goto-layout splits
                    kitty @ (__kt_to) launch --location=vsplit --location=after --cwd=current
                    # Resize to make right column thinner (30% of width)
                    kitty @ (__kt_to) resize-window --axis horizontal --increment -20

                case 3 triple
                    # Create tab with 3 splits (1 left, 2 right)
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
                    kitty @ (__kt_to) launch --location=vsplit --cwd=current
                    kitty @ (__kt_to) launch --location=hsplit --cwd=current

                case 2 dual split
                    # Create tab with 2 vertical splits (50/50)
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
                    kitty @ (__kt_to) launch --location=vsplit --cwd=current

                case h horizontal
                    # Create tab with 2 horizontal splits
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
                    kitty @ (__kt_to) launch --location=hsplit --cwd=current

                case '*'
                    # Create single window tab
                    if test -n "$layout"
                        set argv $layout $argv
                    end
                    kitty @ (__kt_to) launch --type=tab --tab-title="$argv" --cwd=current
            end

        case list ls
            # List all tabs with id and title
            kitty @ (__kt_to) ls | jq -r '.[] | .tabs[] | "\(.id): \(.title)"'

        case focus goto
            # Focus a specific tab by id or title
            if test (count $argv) -eq 0
                echo "Usage: kt focus <id_or_title>"
                return 1
            end
            # Check if argument is numeric (id) or string (title)
            if string match -qr '^[0-9]+$' -- $argv[1]
                kitty @ (__kt_to) focus-tab --match "id:$argv[1]"
            else
                kitty @ (__kt_to) focus-tab --match "title:$argv"
            end

        case close
            # Close current tab
            kitty @ (__kt_to) close-tab

        case help '*'
            echo "Kitty Tab Helper - Manage tabs and splits easily"
            echo ""
            echo "Commands:"
            echo "  kt name <title>        - Set current tab title"
            echo "  kt new [layout] [title] - Create new tab with layout"
            echo "    Layouts:"
            echo "      dev         - 2 columns (70/30) - wide left, thin right for chat"
            echo "      4/quad      - 2x2 grid of equal splits"
            echo "      3/triple    - 3 splits (1 left, 2 right stacked)"
            echo "      2/dual      - 2 equal vertical splits"
            echo "      h/horizontal - 2 horizontal splits (top/bottom)"
            echo "  kt list               - List all tabs (id: title)"
            echo "  kt focus <tab>        - Focus tab by id (number) or title"
            echo "  kt close              - Close current tab"
            echo ""
            echo "Examples:"
            echo "  kt name 'Main Dev'"
            echo "  kt new dev 'Codex Session'  - 70/30 split for dev + chat"
            echo "  kt new 4 'Monitoring'        - 2x2 grid for monitoring"
            echo "  kt new 2 'API Work'          - Equal vertical split"
    end
end