function hd --description 'Open Hunk diff review UI'
    if test (count $argv) -eq 0; or contains -- $argv[1] help --help -h
        echo "hd - Hunk diff helper"
        echo ""
        echo "Usage:"
        echo "  hd                          Show this help"
        echo "  hd staged                   Review staged changes"
        echo "  hd wt [args...]             Review a selected worktree"
        echo "  hd wt staged                Review its staged changes"
        echo "  hd <ref|range|args...>      Forwarded verbatim to `hunk diff`"
        echo ""
        echo "Examples:"
        echo "  hd main                     Review working tree against main"
        echo "  hd main...HEAD              Review the merge-base range"
        echo "  hd HEAD~1                   Review against one commit back"
        echo "  hd staged                   Review staged changes"
        echo "  hd main -- src/ui           Review against main, scoped to src/ui"
        echo "  hd before.ts after.ts       Compare two files on disk"
        echo "  hd --watch                  Review working tree, auto-reload on change"
        echo "  hd wt                       Pick a worktree, review its uncommitted changes"
        echo "  hd wt main...HEAD           Pick a worktree, review its branch work"
        echo "                              (refs resolve inside the picked worktree)"
        echo ""
        echo "Refs are shared across worktrees: reviewing committed work never needs"
        echo "the worktree itself — `hd main...<branch>` works from anywhere in the"
        echo "repo. Use `hd wt` to reach a worktree's uncommitted state, or when you"
        echo "only know the worktree, not its branch name. `cwt` jumps there instead."
        echo ""
        echo "Anything that isn't `staged` is passed through to `hunk diff`."
        echo "For the full Hunk option list:  hunk diff --help"
        return 0
    end

    set -l worktree
    if test "$argv[1]" = wt
        set worktree (__pick_git_worktree)
        set -l picker_status $status
        if test $picker_status -ne 0
            return $picker_status
        end
        set -e argv[1]
    end

    set -l hunk_args $argv
    if test (count $hunk_args) -gt 0; and test "$hunk_args[1]" = staged
        set hunk_args --staged $hunk_args[2..-1]
    end

    if test -n "$worktree"
        # A worktree registration can disappear after selection but before launch.
        if not test -d "$worktree"
            echo "hd: selected worktree no longer exists: $worktree" >&2
            return 1
        end

        command fish --no-config -c 'cd -- "$argv[1]"; or exit 1; exec hunk diff $argv[2..-1]' -- "$worktree" $hunk_args
    else
        command hunk diff $hunk_args
    end
end
