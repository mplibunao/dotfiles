function emm-run --description 'WizyEMM: start the dev server (eu dev)'
    set -l root (__emm_find_root); or return 1
    mvn appengine:run -e \
        -P eu,dev \
        -f "$root/emm-backend-webhost/pom.xml" $argv
end
