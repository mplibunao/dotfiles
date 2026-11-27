function __pick_git_worktree --description 'Select a usable Git worktree and print its absolute path'
    set -l porcelain (command git worktree list --porcelain -z | string split0)
    set -l git_status $pipestatus[1]
    if test $git_status -ne 0
        echo "__pick_git_worktree: failed to list Git worktrees" >&2
        return 1
    end

    set -l paths
    set -l labels
    set -l stale_count 0

    set -l path
    set -l head
    set -l branch
    set -l is_detached 0
    set -l is_bare 0
    set -l is_prunable 0

    for line in $porcelain __pick_git_worktree_end__
        if string match -q 'worktree *' -- $line; or test "$line" = __pick_git_worktree_end__
            if test -n "$path"
                # Row transport is line/tab-delimited by design, so those paths are excluded rather than NUL-framed end to end.
                if test $is_prunable -eq 1; or not test -d "$path"; or string match -rq '[\t\n]' -- "$path"
                    set stale_count (math $stale_count + 1)
                else if test $is_bare -eq 0
                    if test $is_detached -eq 1
                        set -a labels "detached @ "(string sub -s 1 -l 8 -- $head)
                    else
                        set -a labels (string replace -r '^refs/heads/' '' -- $branch)
                    end
                    set -a paths "$path"
                end
            end

            if test "$line" = __pick_git_worktree_end__
                break
            end

            set path (string replace -r '^worktree ' '' -- $line)
            set head
            set branch
            set is_detached 0
            set is_bare 0
            set is_prunable 0
            continue
        end

        switch $line
            case 'HEAD *'
                set head (string replace 'HEAD ' '' -- $line)
            case 'branch *'
                set branch (string replace 'branch ' '' -- $line)
            case detached
                set is_detached 1
            case bare
                set is_bare 1
            case 'prunable*'
                set is_prunable 1
        end
    end

    if test (count $paths) -eq 0
        echo "__pick_git_worktree: no usable worktrees; excluded $stale_count stale or unrepresentable registration(s)" >&2
        return 1
    end

    set -l rows
    for index in (seq (count $paths))
        # The hidden index keeps the parsed path authoritative even when it contains spaces.
        set -a rows (printf '%s\t%s  %s' $index $labels[$index] $paths[$index])
    end

    set -l selected (printf '%s\n' $rows | command fzf --no-multi --delimiter=\t --with-nth=2)
    set -l fzf_status $status
    if contains -- $fzf_status 1 130
        return 130
    else if test $fzf_status -ne 0
        echo "__pick_git_worktree: fzf failed with status $fzf_status" >&2
        return 1
    end

    set -l selected_index (string split -m 1 \t -- $selected)[1]
    if not string match -rq '^[1-9][0-9]*$' -- $selected_index; or test $selected_index -gt (count $paths)
        echo "__pick_git_worktree: fzf returned an invalid selection" >&2
        return 1
    end

    printf '%s\n' $paths[$selected_index]
end
