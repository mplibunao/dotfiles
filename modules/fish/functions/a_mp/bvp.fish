function bvp --description 'Preview beads issues as static site'
    argparse h/help w/watch 'title=' exclude-closed exclude-history -- $argv
    or return

    # Help text
    if set -q _flag_help
        echo "bvp - Preview beads issues as static site"
        echo ""
        echo "Usage: bvp [options]"
        echo ""
        echo "Options:"
        echo "  -h, --help             Show this help"
        echo "  -w, --watch            Watch for changes and auto re-export"
        echo "      --title=TITLE      Set page title"
        echo "      --exclude-closed   Exclude closed issues"
        echo "      --exclude-history  Exclude git history"
        echo ""
        echo "Examples:"
        echo "  bvp                    Export and preview (one-shot)"
        echo "  bvp --watch            Watch for changes"
        echo "  bvp --title='Sprint 1'  # Set custom title"
        return 0
    end

    # Check bv is available
    if not command -q bv
        echo "Error: bv not found. Install beads_viewer first." >&2
        return 1
    end

    # Detect repo root
    set -l repo_root (command git rev-parse --show-toplevel 2>/dev/null)
    if test -z "$repo_root"; and set -q DOTFILES_DIR
        set repo_root "$DOTFILES_DIR"
    end
    if test -z "$repo_root"
        echo "Error: not in a git repo and DOTFILES_DIR not set" >&2
        return 1
    end

    set -l preview_dir "$repo_root/.bv-preview"
    set -l beads_dir "$repo_root/.beads"

    # Check .beads/ exists
    if not test -d "$beads_dir"
        echo "Error: no .beads/ directory found in $repo_root" >&2
        echo "Run 'bd init' to initialize beads tracking" >&2
        return 1
    end

    # Build export args
    set -l export_args --export-pages "$preview_dir"
    if set -q _flag_title
        set -a export_args --pages-title "$_flag_title"
    end
    if set -q _flag_exclude_closed
        set -a export_args --pages-exclude-closed
    end
    if set -q _flag_exclude_history
        set -a export_args --pages-exclude-history
    end

    # Save original directory and cd to repo root (bv expects to run from repo root)
    set -l original_pwd "$PWD"
    cd -- "$repo_root"; or return 1

    # Minimal handler to restore PWD if interrupted during export
    # (will be replaced by full handler in watch mode, or erased in one-shot mode)
    set -g __bvp_restore_pwd "$original_pwd"
    function __bvp_pwd_restore --on-signal INT --on-signal TERM
        set -q __bvp_restore_pwd; and cd -- "$__bvp_restore_pwd"
        set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
        functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore
    end

    # Watch mode
    if set -q _flag_watch
        # Check fswatch is available
        if not command -q fswatch
            echo "Error: fswatch not found. Install via nix or brew." >&2
            cd -- "$original_pwd"
            set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
            functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore
            return 1
        end

        # Initial export BEFORE defining handlers (avoid leaking on failure)
        echo "Initial export to $preview_dir..."
        command bv $export_args
        if test $status -ne 0
            cd -- "$original_pwd"
            set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
            functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore
            return 1
        end

        # Remove temp handler - full cleanup handler takes over
        set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
        functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore

        # Now define globals and handlers (only after successful initial export)
        set -g __bvp_server_pid ""
        set -g __bvp_watcher_pids
        set -g __bvp_cleaned 0
        set -g __bvp_original_pwd "$original_pwd"

        # Cleanup implementation - idempotent, shared by signal handler and normal exit
        function __bvp_cleanup_impl
            # Guard against double cleanup (Ctrl+C then normal exit)
            if test "$__bvp_cleaned" = 1
                return 0
            end
            set -g __bvp_cleaned 1

            # Kill all watcher processes; try treating each PID as a process group first
            for pid in $__bvp_watcher_pids
                # Try process group kill first, then single PID
                kill -TERM -$pid 2>/dev/null; or kill $pid 2>/dev/null
            end
            # Kill server if running
            test -n "$__bvp_server_pid"; and kill $__bvp_server_pid 2>/dev/null
            set -e __bvp_watcher_pids
            set -e __bvp_server_pid
            # Restore original directory
            test -n "$__bvp_original_pwd"; and cd -- "$__bvp_original_pwd"
            set -e __bvp_original_pwd
        end

        # Signal handler - wraps cleanup impl (does NOT erase functions)
        function __bvp_cleanup --on-signal INT --on-signal TERM
            echo ""
            echo "Shutting down..."
            __bvp_cleanup_impl
        end

        # Start preview server in background
        echo "Starting preview server (runs in background for watch mode)..."
        command bv --preview-pages "$preview_dir" &
        set -g __bvp_server_pid $last_pid

        # Give server time to start and verify it's running
        command sleep 1
        if not kill -0 $__bvp_server_pid 2>/dev/null
            echo "Error: preview server failed to start." >&2
            __bvp_cleanup_impl
            functions -e __bvp_cleanup
            functions -e __bvp_cleanup_impl
            set -e __bvp_cleaned
            return 1
        end

        echo "Watching $beads_dir for changes (Ctrl+C to stop)..."
        echo ""

        # Start fswatch in a subprocess (fish -c) so it properly backgrounds
        # Plain `cmd &` in Fish doesn't background pipelines reliably
        # Note: export_args must be serialized for subprocess; use string escape to prevent
        # command injection via user-controlled flags like --title
        # beads_dir is passed via env var to avoid shell injection with paths containing special chars
        set -l export_args_escaped (string escape -- $export_args | string join ' ')
        env BEADS_DIR="$beads_dir" fish -c "
            set -l export_args $export_args_escaped
            fswatch -o -l 1.0 -e '.*' -i 'issues\.jsonl\$' \"\$BEADS_DIR\" | while read -l count
                echo '['(date +%H:%M:%S)'] Change detected, re-exporting...'
                if env BV_NO_BROWSER=1 command bv \$export_args
                    echo '['(date +%H:%M:%S)'] Done. Refresh browser to see changes.'
                else
                    echo '['(date +%H:%M:%S)'] Export failed (see errors above); watching continues.' >&2
                end
                echo ''
            end
        " &
        set -g __bvp_watcher_pids $last_pid

        # Verify watcher started
        if not kill -0 $__bvp_watcher_pids 2>/dev/null
            echo "Error: failed to start watcher process." >&2
            __bvp_cleanup_impl
            functions -e __bvp_cleanup
            functions -e __bvp_cleanup_impl
            set -e __bvp_cleaned
            return 1
        end

        # Wait for watcher using bash subprocess. We don't rely on Fish --on-signal firing
        # on Ctrl+C; we rely on bash exiting on SIGINT so Fish resumes and performs cleanup.
        # See: https://github.com/fish-shell/fish-shell/issues/10193
        # The --on-signal handler above is fallback for signals sent directly to Fish.
        command env -u BASH_ENV -u ENV bash --noprofile --norc -c '
            trap "exit 130" INT
            trap "exit 143" TERM
            trap "exit 129" HUP
            pid=$1
            while kill -0 -- "$pid" 2>/dev/null; do
                sleep 1
            done
        ' bvp-watch $__bvp_watcher_pids

        # CRITICAL: Cleanup is unconditional - capture status, cleanup, return status
        # This ensures cleanup runs even when bash exits with 130 (SIGINT)
        set -l wait_status $status
        __bvp_cleanup_impl
        functions -e __bvp_cleanup
        functions -e __bvp_cleanup_impl
        set -e __bvp_cleaned
        return $wait_status
    end

    # One-shot mode: export and preview
    echo "Exporting to $preview_dir..."
    command bv $export_args
    if test $status -ne 0
        cd -- "$original_pwd"
        set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
        functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore
        return 1
    end

    # Remove temp handler before long-running preview
    set -q __bvp_restore_pwd; and set -e __bvp_restore_pwd
    functions -q __bvp_pwd_restore; and functions -e __bvp_pwd_restore

    echo "Starting preview server (Ctrl+C to stop)..."
    command bv --preview-pages "$preview_dir"
    set -l exit_status $status
    cd -- "$original_pwd"
    return $exit_status
end
