function kdev --description 'Launch development environment with specific tools'
    # Helper: build --to args for socket-only remote control
    # Uses KITTY_LISTEN_ON if available, else falls back to user-scoped socket
    # NOTE: Each arg on separate line - fish command substitution splits on newlines only
    function __kdev_to
        if test -n "$KITTY_LISTEN_ON"
            printf '%s\n' "--to" "$KITTY_LISTEN_ON"
        else
            printf '%s\n' "--to" "unix:/tmp/kitty-$USER"
        end
    end

    set -l profile $argv[1]
    set -l title $argv[2]

    # Set default title if not provided
    if test -z "$title"
        set title $profile
    end

    switch $profile
        case codex
            # Codex development setup - main + chat column
            kitty @ (__kdev_to) launch --type=tab --tab-title="Codex: $title" --cwd=current
            kitty @ (__kdev_to) goto-layout splits

            # Right pane for chat/logs (30% width)
            kitty @ (__kdev_to) launch --location=vsplit --location=after --cwd=current
            kitty @ (__kdev_to) resize-window --axis horizontal --increment -20

            # Optional: Start codex in right pane
            # kitty @ (__kdev_to) send-text --match index:0 "codex\n"

        case claude
            # ClaudeCode setup - main + chat
            kitty @ (__kdev_to) launch --type=tab --tab-title="Claude: $title" --cwd=current
            kitty @ (__kdev_to) goto-layout splits

            # Right pane for ClaudeCode chat
            kitty @ (__kdev_to) launch --location=vsplit --location=after --cwd=current
            kitty @ (__kdev_to) resize-window --axis horizontal --increment -20

            # Optional: Start claude in right pane
            # kitty @ (__kdev_to) send-text --match index:0 "claude\n"

        case monitor
            # System monitoring - 4 panes for different monitors
            kitty @ (__kdev_to) launch --type=tab --tab-title="Monitor: $title" --cwd=current
            kitty @ (__kdev_to) goto-layout grid

            # Create 3 more panes
            kitty @ (__kdev_to) launch --location=vsplit --cwd=current
            kitty @ (__kdev_to) launch --location=hsplit --cwd=current
            kitty @ (__kdev_to) focus-window --match neighbor:left
            kitty @ (__kdev_to) launch --location=hsplit --cwd=current

            # Launch monitoring tools in each pane
            kitty @ (__kdev_to) send-text --match index:0 "btm\n"  # bottom - system monitor
            kitty @ (__kdev_to) send-text --match index:1 "lazygit\n"  # git status
            kitty @ (__kdev_to) send-text --match index:2 "lazydocker\n"  # docker monitor
            # Fourth pane stays as shell

        case logs
            # Log viewing setup - main + 2 log panes
            kitty @ (__kdev_to) launch --type=tab --tab-title="Logs: $title" --cwd=current
            kitty @ (__kdev_to) launch --location=hsplit --cwd=current
            kitty @ (__kdev_to) launch --location=vsplit --cwd=current

        case git
            # Git workflow - main + lazygit
            kitty @ (__kdev_to) launch --type=tab --tab-title="Git: $title" --cwd=current
            kitty @ (__kdev_to) launch --location=vsplit --cwd=current
            kitty @ (__kdev_to) send-text --match index:1 "lazygit\n"

        case help '*'
            echo "Kitty Development Environment Launcher"
            echo ""
            echo "Usage: kdev <profile> [title]"
            echo ""
            echo "Profiles:"
            echo "  codex    - Main window + thin chat column (70/30)"
            echo "  claude   - Main window + ClaudeCode chat (70/30)"
            echo "  monitor  - 4-pane grid with system monitors"
            echo "  logs     - 3-pane log viewing setup"
            echo "  git      - Main + lazygit side-by-side"
            echo ""
            echo "Examples:"
            echo "  kdev codex 'Project API'    - Codex layout for API work"
            echo "  kdev monitor 'Production'   - 4-pane monitoring setup"
            echo "  kdev claude 'Bug Fix'       - ClaudeCode development layout"
    end
end