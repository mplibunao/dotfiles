function lsg --description 'List files and filter by pattern (grep)'
    if test (count $argv) -eq 0
        echo "Usage: lsg <pattern>"
        return 1
    end
    lsd --hyperlink=auto --color=auto | command grep -i $argv
end
