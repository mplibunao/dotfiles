function aerospace-layout --description 'Save and restore AeroSpace workspace layouts'
    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case save
            if test -z "$argv[1]"
                echo "Usage: aerospace-layout save <name>" >&2
                return 1
            end
            _aerospace_layout_save $argv[1]
        case restore
            if test -z "$argv[1]"
                echo "Usage: aerospace-layout restore <name> [--dry-run] [--launch]" >&2
                return 1
            end
            _aerospace_layout_restore $argv
        case list ls
            _aerospace_layout_list
        case delete rm
            if test -z "$argv[1]"
                echo "Usage: aerospace-layout delete <name>" >&2
                return 1
            end
            _aerospace_layout_delete $argv[1]
        case show
            if test -z "$argv[1]"
                echo "Usage: aerospace-layout show <name>" >&2
                return 1
            end
            _aerospace_layout_show $argv[1]
        case help -h --help ''
            echo "Usage: aerospace-layout <command> [name] [options]"
            echo ""
            echo "Save and restore workspace routing (app -> workspace assignments)."
            echo ""
            echo "Commands:"
            echo "  save <name>               Save current layout"
            echo "  restore <name>            Restore saved layout"
            echo "  restore <name> --dry-run  Preview restore without changes"
            echo "  restore <name> --launch   Launch missing apps"
            echo "  list                      List saved layouts"
            echo "  show <name>               Show layout details"
            echo "  delete <name>             Delete a layout"
            echo "  help                      Show this help"
            echo ""
            echo "Layout names: lowercase, numbers, hyphens, underscores (max 32 chars)"
            echo ""
            echo "Title matching: exact -> substring -> any (deterministic order)"
            return 0
        case '*'
            echo "Unknown command: $cmd" >&2
            echo "Run 'aerospace-layout help' for usage" >&2
            return 1
    end
end

# Shared validation function for layout names (prevents path traversal)
function _aerospace_layout_validate_name --description 'Validate layout name'
    set -l name $argv[1]
    if not string match -rq '^[a-z][a-z0-9_-]{0,31}$' -- "$name"
        echo "Invalid layout name: $name" >&2
        echo "Use lowercase letters, numbers, hyphens, underscores (max 32 chars)" >&2
        return 1
    end
    return 0
end

# Shared dependency check
function _aerospace_layout_check_deps --description 'Check required dependencies'
    if not type -q aerospace
        echo "Missing dependency: aerospace" >&2
        return 1
    end
    if not type -q jq
        echo "Missing dependency: jq" >&2
        return 1
    end
    return 0
end

function _aerospace_layout_save --description 'Save current window arrangement'
    set -l name $argv[1]
    set -l layout_dir ~/.config/aerospace-layouts

    # Validate layout name (security: prevent path injection)
    _aerospace_layout_validate_name $name
    or return 1

    # Check dependencies
    _aerospace_layout_check_deps
    or return 1

    mkdir -p $layout_dir

    # Capture current state (lock scope: focused monitor)
    set -l focused_ws (aerospace list-workspaces --focused --format '%{workspace}' | string trim)
    set -l windows_json (aerospace list-windows --monitor focused --json \
        --format '%{window-id}%{app-bundle-id}%{workspace}%{window-title}' | string collect)

    # Atomic write: temp file on SAME filesystem, then rename
    set -l tmp_file (mktemp "$layout_dir/$name.XXXXXX")
    or begin
        echo "Failed to create temp file" >&2
        return 1
    end

    # Build layout JSON - MUST sort_by before group_by for correct grouping
    printf '%s' $windows_json | jq --arg name "$name" --arg focused "$focused_ws" '{
        schema_version: 1,
        name: $name,
        created_at: (now | todateiso8601),
        scope: "focused-monitor",
        focused_workspace: $focused,
        windows: (
            sort_by(.["app-bundle-id"]) |
            group_by(.["app-bundle-id"]) |
            map({
                app_bundle_id: .[0]["app-bundle-id"],
                workspace: .[0].workspace,
                count: length,
                window_titles: map(.["window-title"])
            })
        )
    }' >"$tmp_file"
    or begin
        rm -f "$tmp_file"
        echo "Failed to generate layout JSON" >&2
        return 1
    end

    # Verify non-empty before atomic rename
    if not test -s "$tmp_file"
        rm -f "$tmp_file"
        echo "Generated empty layout" >&2
        return 1
    end

    # Atomic rename with error handling
    mv -f "$tmp_file" "$layout_dir/$name.json"
    or begin
        rm -f "$tmp_file"
        echo "Failed to write layout file" >&2
        return 1
    end

    echo "Saved layout: $name"
end

function _aerospace_layout_restore --description 'Restore a saved layout'
    set -l name $argv[1]
    set -l dry_run false
    set -l launch_missing false

    # Parse flags
    if contains -- --dry-run $argv
        set dry_run true
    end
    if contains -- --launch $argv
        set launch_missing true
    end

    # Validate layout name (security: prevent path traversal)
    _aerospace_layout_validate_name $name
    or return 1

    # Check dependencies
    _aerospace_layout_check_deps
    or return 1

    set -l layout_dir ~/.config/aerospace-layouts
    set -l layout_file "$layout_dir/$name.json"

    if not test -f "$layout_file"
        echo "Layout not found: $name" >&2
        return 1
    end

    # Validate JSON schema before proceeding
    jq -e '.schema_version == 1 and (.windows | type == "array")' "$layout_file" >/dev/null 2>&1
    or begin
        echo "Invalid layout file (schema mismatch): $name" >&2
        return 1
    end

    # Preflight: validate workspaces exist (including focused_workspace)
    set -l existing_ws (aerospace list-workspaces --all --format '%{workspace}')
    set -l required_ws (jq -r '.windows[].workspace' "$layout_file" | env LC_ALL=C sort -u)
    for ws in $required_ws
        if not contains -- $ws $existing_ws
            echo "Workspace '$ws' in layout does not exist" >&2
            return 1
        end
    end

    # Validate focused_workspace exists
    set -l layout_focused_ws (jq -r '.focused_workspace // empty' "$layout_file")
    if test -z "$layout_focused_ws"
        echo "Layout missing focused_workspace: $name" >&2
        return 1
    end
    if not contains -- $layout_focused_ws $existing_ws
        echo "Focused workspace '$layout_focused_ws' in layout does not exist" >&2
        return 1
    end

    # Lock scope at start
    set -l scope_monitor focused

    # Get current windows (fresh per-restore) with validation
    set -l current_json (aerospace list-windows --monitor $scope_monitor --json \
        --format '%{window-id}%{app-bundle-id}%{workspace}%{window-title}' | string collect)
    or begin
        echo "Failed to query current windows from AeroSpace" >&2
        return 1
    end

    # Validate JSON before proceeding
    printf '%s' $current_json | jq -e 'type == "array"' >/dev/null 2>&1
    or begin
        echo "AeroSpace returned invalid JSON for list-windows" >&2
        return 1
    end

    # Get list of running app bundle IDs
    set -l running_apps (printf '%s' $current_json | jq -r '.[]["app-bundle-id"]' | env LC_ALL=C sort -u)

    # Get required apps from layout
    set -l required_apps (jq -r '.windows[].app_bundle_id' "$layout_file" | env LC_ALL=C sort -u)

    # Handle missing apps
    for app_id in $required_apps
        if not contains -- $app_id $running_apps
            if $launch_missing
                _aerospace_layout_launch_and_wait $app_id $dry_run
            else if not $dry_run
                echo "App not running: $app_id (use --launch to start)"
            end
        end
    end

    # Refresh current windows after launches
    if $launch_missing; and not $dry_run
        set current_json (aerospace list-windows --monitor $scope_monitor --json \
            --format '%{window-id}%{app-bundle-id}%{workspace}%{window-title}' | string collect)
    end

    # Track consumed window IDs to prevent double-moves
    set -l consumed_wids

    # Use unit separator to safely pack window data (colons appear in titles)
    set -l sep (printf '\x1f')

    # Process each layout entry using jq -c (safe for titles with special chars)
    for rule_json in (jq -c '.windows[]' "$layout_file")
        set -l app_bundle_id (printf '%s' $rule_json | jq -r '.app_bundle_id')
        set -l target_ws (printf '%s' $rule_json | jq -r '.workspace')
        set -l count (printf '%s' $rule_json | jq -r '.count // 1')
        set -l title_hints (printf '%s' $rule_json | jq -r '.window_titles[]?' 2>/dev/null)

        # Get windows for this app
        set -l app_windows_json (printf '%s' $current_json | jq -c \
            --arg app "$app_bundle_id" '[.[] | select(.["app-bundle-id"] == $app)]')

        # Build candidate lists using unit separator (safe delimiter)
        set -l already_correct # wid<sep>title
        set -l can_move # wid<sep>title<sep>current_ws

        for win in (printf '%s' $app_windows_json | jq -c '.[]')
            set -l wid (printf '%s' $win | jq -r '.["window-id"]')
            set -l wtitle (printf '%s' $win | jq -r '.["window-title"]')
            set -l wws (printf '%s' $win | jq -r '.workspace')

            # Skip if already consumed
            if contains -- $wid $consumed_wids
                continue
            end

            if test "$wws" = "$target_ws"
                set -a already_correct "$wid$sep$wtitle"
            else
                set -a can_move "$wid$sep$wtitle$sep$wws"
            end
        end

        # Calculate how many we need to move
        set -l satisfied (count $already_correct)
        set -l need_to_move (math "max(0, $count - $satisfied)")

        # Mark already-correct as consumed
        for entry in $already_correct
            set -l wid (string split -- $sep "$entry")[1]
            set -a consumed_wids $wid
        end

        if test $need_to_move -eq 0
            continue
        end

        # Select windows to move using three-tier matching
        set -l wids_to_move
        set -l remaining $need_to_move

        # Tier 1: Exact title match
        for hint in $title_hints
            if test $remaining -le 0
                break
            end
            for entry in $can_move
                set -l parts (string split -- $sep "$entry")
                set -l wid $parts[1]
                set -l wtitle $parts[2]
                if contains -- $wid $consumed_wids
                    continue
                end
                if test "$wtitle" = "$hint"
                    set -a wids_to_move $wid
                    set -a consumed_wids $wid
                    set remaining (math "$remaining - 1")
                    break
                end
            end
        end

        # Tier 2: Substring match (case-insensitive, literal not glob)
        if test $remaining -gt 0
            for hint in $title_hints
                if test $remaining -le 0
                    break
                end
                set -l hint_lower (string lower -- "$hint")
                # Escape regex special chars for literal substring match
                set -l hint_escaped (string escape --style=regex -- "$hint_lower")
                for entry in $can_move
                    set -l parts (string split -- $sep "$entry")
                    set -l wid $parts[1]
                    set -l wtitle $parts[2]
                    if contains -- $wid $consumed_wids
                        continue
                    end
                    set -l wtitle_lower (string lower -- "$wtitle")
                    # Use regex match with escaped pattern for literal substring
                    if string match -rq -- "$hint_escaped" "$wtitle_lower"
                        set -a wids_to_move $wid
                        set -a consumed_wids $wid
                        set remaining (math "$remaining - 1")
                        break
                    end
                end
            end
        end

        # Tier 3: Any remaining (sorted for determinism)
        if test $remaining -gt 0
            # Sort with LC_ALL=C for deterministic ordering across locales
            for entry in (printf '%s\n' $can_move | env LC_ALL=C sort)
                if test $remaining -le 0
                    break
                end
                set -l wid (string split -- $sep "$entry")[1]
                if contains -- $wid $consumed_wids
                    continue
                end
                set -a wids_to_move $wid
                set -a consumed_wids $wid
                set remaining (math "$remaining - 1")
            end
        end

        # Execute moves (or print for dry-run)
        for wid in $wids_to_move
            if $dry_run
                echo "[DRY-RUN] Move window $wid ($app_bundle_id) -> workspace $target_ws"
            else
                aerospace move-node-to-workspace --window-id "$wid" "$target_ws"
            end
        end
    end

    # Restore focus
    set -l focused_ws (jq -r '.focused_workspace' "$layout_file")
    if $dry_run
        echo "[DRY-RUN] Focus workspace $focused_ws"
    else
        aerospace workspace "$focused_ws"
    end

    if $dry_run
        echo "Dry run complete - no changes made"
    else
        echo "Restored layout: $name"
        # Show notification for GUI feedback
        osascript -e "display notification \"Layout restored\" with title \"$name\"" 2>/dev/null &
    end
end

function _aerospace_layout_launch_and_wait --description 'Launch app and wait for window'
    set -l app_id $argv[1]
    set -l dry_run $argv[2]
    set -l timeout_s 10
    set -l interval_s 0.5
    # Use integer iteration count to avoid float comparison bugs
    set -l max_iters (math "ceil($timeout_s / $interval_s)")

    if test "$dry_run" = true
        echo "[DRY-RUN] Would launch: $app_id"
        return 0
    end

    echo "Launching: $app_id"

    # Launch in background (don't steal focus)
    open -g -b $app_id 2>/dev/null
    or begin
        echo "  -> Failed to launch $app_id" >&2
        return 1
    end

    # Poll until window appears or timeout (using integer iteration)
    for i in (seq 1 $max_iters)
        # Default to 0 on any jq/aerospace failure (graceful degradation)
        set -l window_count (aerospace list-windows --monitor focused --json \
            --format '%{window-id}%{app-bundle-id}' 2>/dev/null | \
            jq --arg app "$app_id" '[.[] | select(.["app-bundle-id"] == $app)] | length' 2>/dev/null)
        or set window_count 0

        if test "$window_count" -gt 0
            echo "  -> Window appeared for $app_id"
            return 0
        end

        sleep $interval_s
    end

    echo "  -> Timeout waiting for $app_id window" >&2
    return 1
end

function _aerospace_layout_list --description 'List saved layouts'
    set -l layout_dir ~/.config/aerospace-layouts

    if not test -d "$layout_dir"
        echo "No layouts saved yet"
        return 0
    end

    set -l layouts $layout_dir/*.json
    if test (count $layouts) -eq 0; or not test -f "$layouts[1]"
        echo "No layouts saved yet"
        return 0
    end

    # Check jq is available for listing
    if not type -q jq
        echo "Missing dependency: jq" >&2
        return 1
    end

    echo "Saved layouts:"
    for layout in $layouts
        set -l name (basename $layout .json)
        set -l created (jq -r '.created_at // "unknown"' "$layout")
        set -l app_count (jq -r '.windows | length' "$layout")
        echo "  $name ($app_count apps, created: $created)"
    end
end

function _aerospace_layout_show --description 'Show layout details'
    set -l name $argv[1]

    # Validate layout name (security: prevent path traversal)
    _aerospace_layout_validate_name $name
    or return 1

    # Check jq is available
    if not type -q jq
        echo "Missing dependency: jq" >&2
        return 1
    end

    set -l layout_dir ~/.config/aerospace-layouts
    set -l layout_file "$layout_dir/$name.json"

    if not test -f "$layout_file"
        echo "Layout not found: $name" >&2
        return 1
    end

    echo "Layout: $name"
    echo ""
    jq -r '
        "Created: \(.created_at)",
        "Focused workspace: \(.focused_workspace)",
        "Scope: \(.scope)",
        "",
        "Windows:",
        (.windows[] | "  \(.app_bundle_id) -> workspace \(.workspace) (count: \(.count))")
    ' "$layout_file"
end

function _aerospace_layout_delete --description 'Delete a layout'
    set -l name $argv[1]

    # Validate layout name (security: prevent path traversal)
    _aerospace_layout_validate_name $name
    or return 1

    set -l layout_dir ~/.config/aerospace-layouts
    set -l layout_file "$layout_dir/$name.json"

    if not test -f "$layout_file"
        echo "Layout not found: $name" >&2
        return 1
    end

    rm -f "$layout_file"
    echo "Deleted layout: $name"
end
