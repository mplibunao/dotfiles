function clm --description 'Launch Claude Code with strict MCP configurations'
    # CLM - Claude MCP Launcher
    # ==========================
    # This function launches Claude Code with STRICT MCP server configurations,
    # turning off ALL default MCP servers and loading ONLY what you specify.
    # context/repo-prompt-ce is prepended unless a RepoPrompt config is already
    # explicit, so RepoPrompt CE is available as the daily-driver MCP.
    # WHY THIS APPROACH?
    # ------------------
    # 1. Complete control - NO default MCP servers loaded
    # 2. Faster startup - only loads exactly what you need
    # 3. Project-specific configurations without interference
    # 4. Use 'claude' for defaults, 'clm' for strict control
    #
    # HOW IT WORKS:
    # -------------
    # MCP configs are stored in $CLM_MCP_CONFIG_DIR (if set) or fallback to:
    #   ~/Projects/personal/ai/claude-toolkit/mcp-configs/
    # Uses --strict-mcp-config flag to disable ALL defaults and load ONLY resolved
    # config(s). context/repo-prompt-ce is prepended unless a RepoPrompt config is
    # already explicit.
    #
    # USAGE:
    # ------
    # clm                                        # Default: load context/repo-prompt-ce MCP only
    # clm wizy/gwa-webapp                        # Wizy GWA tools + RepoPrompt
    # clm context/repo-prompt wizy/gwa-webapp    # Compose RepoPrompt + Wizy GWA
    # clm default/minimal .                      # Minimal tools + default RepoPrompt CE
    # clm -h, --help                             # Show help / list available configurations
    # clm -l, --list                             # Show help / list available configurations
    #
    # AVAILABLE CONFIGS:
    # ------------------
    # - wizy/gwa-webapp: Playwright, Postgres, Sequential Thinking, Context7
    # - database/postgres-local: Just PostgreSQL connection
    # - tools/browser-testing: Just Playwright
    # - default/minimal: Sequential Thinking and Context7 only

    set -l mcp_base_dir (__clm_base_dir)
    if test $status -ne 0
        echo "Error: MCP config directory not found" >&2
        echo "" >&2
        echo "To fix this, either:" >&2
        echo "  1. Create the directory and add MCP configs" >&2
        echo "  2. Set CLM_MCP_CONFIG_DIR to your config directory:" >&2
        echo "     set -Ux CLM_MCP_CONFIG_DIR /path/to/mcp-configs" >&2
        return 1
    end

    # RepoPrompt-friendly MCP timeouts. Per-shell overrides win because of `set -q`.
    set -q MCP_TIMEOUT; or set -gx MCP_TIMEOUT 30000
    set -q MCP_TOOL_TIMEOUT; or set -gx MCP_TOOL_TIMEOUT 10800000
    set -q MAX_MCP_OUTPUT_TOKENS; or set -gx MAX_MCP_OUTPUT_TOKENS 25000

    # Show help only when explicitly requested
    if test (count $argv) -gt 0; and contains -- "$argv[1]" -l --list -h --help
        __clm_show_help "$mcp_base_dir"
        return 0
    end

    # Separate config names from claude args. Config tokens may appear anywhere
    # in argv so users can put Claude flags first, e.g.
    # `clm --dangerously-skip-permissions workflows/kc`.
    set -l config_paths
    set -l claude_args
    set -l passthrough 0

    for arg in $argv
        # The boundary protects prompts and flag values that resemble config names
        # or launcher options; everything after it belongs to Claude verbatim.
        if test $passthrough -eq 1
            set -a claude_args "$arg"
            continue
        else if test "$arg" = --
            set passthrough 1
            continue
        end
        set -l resolved (__clm_resolve_config "$mcp_base_dir" "$arg")
        if test -n "$resolved"
            set -a config_paths "$resolved"
        else
            set -a claude_args $arg
        end
    end

    set -l rp_ce_path (__clm_resolve_config "$mcp_base_dir" "context/repo-prompt-ce")

    set -l rp_config_count 0
    for p in $config_paths
        if __clm_has_repoprompt_server "$p"
            set rp_config_count (math $rp_config_count + 1)
        end
    end
    if test $rp_config_count -gt 1
        echo "Error: choose one RepoPrompt config per session" >&2
        return 1
    end

    if test -n "$rp_ce_path"
        if test $rp_config_count -eq 0
            set -p config_paths "$rp_ce_path"
        end
    end

    if test (count $config_paths) -eq 0
        echo "Error: No valid configuration found in arguments" >&2
        echo "Run 'clm -h' to see available configurations" >&2
        return 1
    end

    # Build display names from resolved paths. A name has to round-trip back through
    # __clm_resolve_config, because the launch log records it and recovery depends on
    # replaying it. Inside the config dir that means the bare name; an external path
    # only resolves while it still ends in .json, so it is recorded verbatim. Anchor the
    # suffix strip so a directory containing ".json" earlier in the path survives.
    set -l config_names
    for p in $config_paths
        if string match -q -- "$mcp_base_dir/*" "$p"
            set -a config_names (string replace "$mcp_base_dir/" "" "$p" | string replace -r '\.json$' '')
        else
            set -a config_names "$p"
        end
    end

    echo "🚀 Launching Claude with strict MCP config(s): "(string join ', ' $config_names)
    echo "   (All default MCP servers disabled)"

    set -l state_home "$HOME/.local/state"
    if set -q XDG_STATE_HOME; and test -n "$XDG_STATE_HOME"
        set state_home "$XDG_STATE_HOME"
    end
    set -l launch_log_dir "$state_home/clm"
    set -l launch_log_path "$launch_log_dir/launches.jsonl"
    set -l config_count (count $config_names)

    # Owner-only: args are recorded verbatim, so a command-line prompt lands here, and
    # $XDG_STATE_HOME may lack a private parent. mkdir -m sets the mode only on a
    # directory it creates; chmod covers one already at umask permissions. The
    # directory is the boundary, not the file inside it.
    command mkdir -p -m 700 "$launch_log_dir" 2>/dev/null
    command chmod 700 "$launch_log_dir" 2>/dev/null

    # Log only into a directory we own. chmod cannot change the mode of a directory
    # owned by someone else, so on a shared $XDG_STATE_HOME the mode above may still be
    # group- or world-readable while the append below would succeed anyway, publishing
    # verbatim arguments. Ownership is the check that makes the 0700 claim true: if we
    # own it the chmod took effect, and if we do not, no log is worth writing there.
    if test -O "$launch_log_dir"
        # tee rather than a `>>` redirect: fish emits its own redirect-failure warning,
        # which survives both 2>/dev/null and an enclosing begin/end, so an unwritable
        # log would print into every launch. tee owns the open instead, and its output
        # is discarded. Logging must stay invisible; it must never interrupt the launch.
        command jq -nc \
            --arg at (command date -u +%Y-%m-%dT%H:%M:%SZ) \
            --arg cwd "$PWD" \
            --argjson config_count "$config_count" \
            --args -- \
            '{at: $at, cwd: $cwd, configs: $ARGS.positional[:$config_count], args: $ARGS.positional[$config_count:]}' \
            $config_names $claude_args 2>/dev/null | command tee -a "$launch_log_path" >/dev/null 2>&1
    end

    command claude --mcp-config $config_paths --strict-mcp-config $claude_args
end

# Add completions: config names while in config prefix, file completion after boundary
complete -c clm -f -n __clm_in_config_prefix -a "(__clm_config_names)"
complete -c clm -n 'not __clm_in_config_prefix'

function __clm_show_help --description 'Display CLM help and available configurations'
    set -l mcp_base_dir $argv[1]
    echo "CLM - Claude MCP Launcher (Strict Mode)"
    echo "========================================"
    echo ""
    echo "Available configurations:"
    echo ""
    for dir in (find $mcp_base_dir -type d -mindepth 1 -maxdepth 1 2>/dev/null | sort)
        set -l dir_name (basename $dir)
        echo "  [$dir_name]"
        for file in (find $dir -name "*.json" -type f 2>/dev/null | sort)
            set -l file_name (basename $file .json)
            set -l servers (cat $file | jq -r '.mcpServers | keys[]' 2>/dev/null)
            if test (count $servers) -gt 0
                echo "    • $dir_name/$file_name" "("(string join ", " $servers)")"
            else
                echo "    • $dir_name/$file_name"
            end
        end
    end
    echo ""
    echo "Usage:"
    echo "  clm <configs...> [claude args]  Launch with ONLY specified MCP servers"
    echo "  clm                             Default: load context/repo-prompt-ce MCP only"
    echo "  clm -h, --help                  Show this help"
    echo "  clm -l, --list                  Show this help"
    echo ""
    echo "Examples:"
    echo "  clm                                     # RepoPrompt CE MCP only (default)"
    echo "  clm wizy/gwa-webapp                     # Wizy GWA stack + RepoPrompt"
    echo "  clm context/repo-prompt wizy/gwa-webapp # Compose RP + Wizy"
    echo "  clm database/postgres-local ~/Projects/myapp"
    echo "  clm default/minimal .                   # Minimal tools + default RepoPrompt CE"
    echo ""
    echo "Note: Uses --strict-mcp-config to disable ALL default MCP servers"
    echo "      context/repo-prompt-ce is prepended unless a config already declares mcpServers.RepoPrompt."
    echo "      Choose one RepoPrompt config per session."
end

function __clm_resolve_config --description 'Resolve a config arg to its full path, or empty if not a config'
    set -l base $argv[1]
    set -l arg $argv[2]
    if test -f "$base/$arg.json"
        echo "$base/$arg.json"
    else if test -f "$base/$arg"
        echo "$base/$arg"
    else if string match -q -- "*.json" "$arg"; and test -f "$arg"
        echo "$arg"
    end
end

function __clm_has_repoprompt_server --description 'Return success when config declares RepoPrompt'
    set -l path $argv[1]
    jq -e '.mcpServers.RepoPrompt? != null' "$path" >/dev/null 2>&1
end

function __clm_in_config_prefix --description 'Offer MCP configurations only while parsing launcher arguments'
    set -l tokens (commandline -opc)
    # The literal Claude suffix must not suggest MCP names.
    if contains -- -- $tokens
        return 1
    end
    set -l mcp_base_dir (__clm_base_dir)
    or return 1
    set -l current (commandline -ct)

    # Config tokens may appear after Claude flags, so completion should not require
    # all prior args to be configs. Avoid offering config names while typing flags.
    if string match -q -- "-*" "$current"
        return 1
    end

    if test -n "$current"
        test -n (__clm_resolve_config "$mcp_base_dir" "$current"); and return 0
        for name in (__clm_config_names)
            string match -q -- "$current*" "$name"; and return 0
        end
        return 1
    end

    return 0
end

function __clm_config_names
    set -l mcp_base_dir (__clm_base_dir)
    or return
    for dir in (find $mcp_base_dir -type d -mindepth 1 -maxdepth 1 2>/dev/null)
        set -l dir_name (basename $dir)
        for file in (find $dir -name "*.json" -type f 2>/dev/null)
            set -l file_name (basename $file .json)
            echo "$dir_name/$file_name"
        end
    end
end

function __clm_base_dir
    if set -q CLM_MCP_CONFIG_DIR; and test -d "$CLM_MCP_CONFIG_DIR"
        echo "$CLM_MCP_CONFIG_DIR"
    else if test -d "$HOME/Projects/personal/ai/claude-toolkit/mcp-configs"
        echo "$HOME/Projects/personal/ai/claude-toolkit/mcp-configs"
    else
        return 1
    end
end
