# Fish completions for hd

function __mp_hd_completing_first_arg
    set -l tokens (commandline -opc)
    set -l current_token (commandline -ct)
    set -l prefix_count 1

    if test (count $tokens) -ge 2; and test "$tokens[2]" = wt
        set prefix_count 2
    end

    if contains -- -- $tokens
        return 1
    end

    if string match -q -- '-*' "$current_token"
        return 1
    end

    if test (count $tokens) -le $prefix_count
        return 0
    end

    if test (count $tokens) -ne (math $prefix_count + 1)
        return 1
    end

    if test -z "$current_token"
        return 1
    end

    return 0
end

function __mp_hd_completing_wrapper_mode
    set -l tokens (commandline -opc)

    if test (count $tokens) -ge 2; and test "$tokens[2]" = wt
        return 1
    end

    __mp_hd_completing_first_arg
end

function __mp_hd_local_branches
    command git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null; or return 0
    command git for-each-ref refs/heads --format='%(refname:short)' 2>/dev/null
end

function __mp_hd_suppress_files
    set -l tokens (commandline -opc)
    set -l current_token (commandline -ct)

    if test -n "$current_token"
        return 1
    end

    if test (count $tokens) -eq 1
        return 0
    end

    if test (count $tokens) -eq 2; and test "$tokens[2]" = wt
        return 0
    end

    return 1
end

complete -c hd -n __mp_hd_suppress_files -f

# First argument suggestions
complete -c hd -n __mp_hd_completing_wrapper_mode -a wt -d 'Review a selected worktree'
complete -c hd -n __mp_hd_completing_first_arg -a staged -d 'Review staged changes'
complete -c hd -n __mp_hd_completing_wrapper_mode -a help -d 'Show help'
complete -c hd -n __mp_hd_completing_first_arg -a HEAD -d 'Review against HEAD'
complete -c hd -n __mp_hd_completing_first_arg -a 'HEAD~1' -d 'Review against one commit back'
complete -c hd -n __mp_hd_completing_first_arg -a '(__mp_hd_local_branches)' -d 'Local branch'

# Focused Hunk option value completions
complete -c hd -l mode -d 'Display mode' -xa 'auto split stack'
complete -c hd -l theme -d 'Theme' -xa 'catppuccin-mocha github-dark-default github-dark-dimmed github-light-default dark-plus'
