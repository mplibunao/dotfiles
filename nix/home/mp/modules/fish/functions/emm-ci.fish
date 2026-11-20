function emm-ci --description 'WizyEMM: clean + install (safe for multi-module changes)'
    set -l root (__emm_find_root); or return 1
    mvn clean install -DskipTests -f "$root/pom.xml" $argv
end
