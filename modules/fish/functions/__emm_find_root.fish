function __emm_find_root --description 'Find wizyemm repo root from current dir'
    set -l dir (pwd)
    while test "$dir" != "/"
        if test -f "$dir/pom.xml"
            if grep -q '<artifactId>wizy-emm</artifactId>' "$dir/pom.xml" 2>/dev/null
                echo "$dir"
                return 0
            end
        end
        set dir (dirname "$dir")
    end
    echo "Error: not inside a wizyemm repo (no pom.xml with artifactId wizy-emm found)" >&2
    return 1
end
