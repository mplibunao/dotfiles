function check-secrets --description "Check required MCP env vars are set"
    function __is_set_and_non_empty --description "Return 0 when var is set and non-empty"
        set -l name $argv[1]
        set -q $name; and test -n "$$name"
    end

    set -l required \
        CONFLUENCE_API_TOKEN \
        JIRA_API_TOKEN \
        SLACK_MCP_XOXC_TOKEN \
        SLACK_MCP_XOXD_TOKEN
    set -l either_required \
        "CONFLUENCE_USERNAME CONFLUENCE_USER" \
        "JIRA_USERNAME JIRA_USER"

    set -l missing 0
    for var in $required
        if not set -q $var
            echo "  MISSING: $var"
            set missing (math $missing + 1)
        else if not __is_set_and_non_empty $var
            echo "  EMPTY: $var"
            set missing (math $missing + 1)
        end
    end

    for group in $either_required
        set -l names (string split ' ' $group)
        set -l found 0
        for name in $names
            if __is_set_and_non_empty $name
                set found 1
                break
            end
        end

        if test $found -eq 0
            echo "  MISSING/EMPTY: one of "(string join ' or ' $names)
            set missing (math $missing + 1)
        end
    end

    if test $missing -eq 0
        echo "All MCP secrets set."
    else
        echo ""
        echo "$missing secret(s) missing. Set with: set -Ux VAR_NAME \"value\""
        echo "See: ~/Projects/personal/ai/claude-toolkit/.codex/secrets.env.example"
    end
end
