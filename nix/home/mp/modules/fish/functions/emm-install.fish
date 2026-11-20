function emm-install --description 'WizyEMM: compile + install all modules (skip tests)'
    set -l root (__emm_find_root); or return 1
    mvn install -Dlocal -DskipTests -f "$root/pom.xml" $argv
end
