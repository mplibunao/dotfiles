function emm-clean --description 'WizyEMM: wipe all target/ dirs'
    set -l root (__emm_find_root); or return 1
    mvn clean -f "$root/pom.xml" $argv
end
