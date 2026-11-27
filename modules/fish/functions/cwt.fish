function cwt --description 'Jump to a selected Git worktree'
    set -l worktree (__pick_git_worktree)
    set -l picker_status $status
    if test $picker_status -ne 0
        return $picker_status
    end

    # A worktree registration can disappear after selection but before navigation.
    if not test -d "$worktree"
        echo "cwt: selected worktree no longer exists: $worktree" >&2
        return 1
    end

    builtin cd -- "$worktree"
end
