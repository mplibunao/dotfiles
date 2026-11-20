function rtk-resync --description 'Re-run rtk init for Claude Code, Codex, Cursor, and OpenCode, link rtk files into claude-toolkit, show toolkit diff'
    if not command -q rtk
        echo "rtk-resync: rtk not on PATH (brew install rtk?)" >&2
        return 1
    end

    set -l toolkit "$HOME/Projects/personal/ai/claude-toolkit"
    if not test -d "$toolkit/.git"
        echo "rtk-resync: $toolkit is not a git repo" >&2
        return 1
    end

    # Live → canonical pairs. rtk 1.2.0 writes through these symlinks.
    # Earlier versions replaced settings.json and AGENTS.md with regular
    # files, so every pair is still checked. rtk also creates the hooks.json
    # files and rtk.ts as regular files when no link exists yet.
    set -l pairs \
        "$HOME/.claude/settings.json"  "$toolkit/settings.json" \
        "$HOME/.claude/RTK.md"         "$toolkit/.claude/RTK.md" \
        "$HOME/.codex/AGENTS.md"       "$toolkit/GLOBAL_AGENTS.md" \
        "$HOME/.codex/RTK.md"          "$toolkit/.codex/RTK.md" \
        "$HOME/.codex/hooks.json"      "$toolkit/.codex/hooks.json" \
        "$HOME/.cursor/hooks.json"     "$toolkit/.cursor/hooks.json" \
        "$HOME/.config/opencode/plugins/rtk.ts" "$toolkit/.opencode/plugins/rtk.ts"

    echo "rtk version: "(rtk --version)
    echo

    echo "==> Claude Code and OpenCode"
    rtk init -g --auto-patch --opencode; or return $status
    echo

    echo "==> Codex"
    rtk init -g --codex; or return $status
    echo

    echo "==> Cursor"
    rtk init -g --agent cursor --auto-patch; or return $status
    echo

    echo "==> Linking rtk's files into the toolkit"
    set -l linked 0
    set -l intact 0
    set -l skipped 0
    for i in (seq 1 2 (count $pairs))
        set -l live $pairs[$i]
        set -l canonical $pairs[(math $i + 1)]

        # rtk leaves a .bak beside a file it changes. The toolkit's git
        # history keeps the previous version, so the .bak is redundant.
        rm -f "$live.bak"

        if test -L "$live"
            set intact (math $intact + 1)
            continue
        end

        if not test -f "$live"
            echo "  ABSENT: $live (skipped)"
            continue
        end

        # Live is a regular file: rtk replaced the link, or there was no
        # link yet. A missing toolkit copy means the toolkit checkout is
        # behind, and copying the file there would block its next pull.
        if not test -f "$canonical"
            echo "  SKIPPED: $live ($canonical is missing; pull the toolkit first)"
            set skipped (math $skipped + 1)
            continue
        end
        if not cmp -s "$live" "$canonical"
            cp "$live" "$canonical"
        end
        rm "$live"
        ln -s "$canonical" "$live"
        echo "  linked: $live -> $canonical"
        set linked (math $linked + 1)
    end
    echo "  ($linked linked, $intact already linked, $skipped skipped)"
    echo

    echo "==> Toolkit diff"
    git -C "$toolkit" --no-pager status --short
    echo
    git -C "$toolkit" --no-pager diff --stat
    echo
    echo "Review:  git -C $toolkit diff"
    echo "Commit:  git -C $toolkit add -A; and git -C $toolkit commit -m 'chore(rtk): resync for '(rtk --version | string split ' ')[2]"
end
