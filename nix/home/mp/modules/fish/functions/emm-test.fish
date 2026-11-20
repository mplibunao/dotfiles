function emm-test --description 'WizyEMM: clean + run tests'
    set -l root (__emm_find_root); or return 1
    mvn clean test -f "$root/pom.xml" $argv
end
