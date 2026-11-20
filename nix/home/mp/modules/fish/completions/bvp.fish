# Fish completions for bvp

# Disable file completions (bvp doesn't take file arguments)
complete -c bvp -f

# Options
complete -c bvp -s h -l help -d 'Show help'
complete -c bvp -s w -l watch -d 'Watch for changes and auto re-export'
complete -c bvp -l title -d 'Page title' -x
complete -c bvp -l exclude-closed -d 'Exclude closed issues'
complete -c bvp -l exclude-history -d 'Exclude git history'
