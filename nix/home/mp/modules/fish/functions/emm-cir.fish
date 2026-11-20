function emm-cir --description 'WizyEMM: clean, install, then run (eu dev)'
    set -l root (__emm_find_root); or return 1
    echo "==> clean"
    mvn clean -f "$root/pom.xml"; or return 1
    echo "==> install"
    mvn install -Dlocal -DskipTests -f "$root/pom.xml"; or return 1
    echo "==> run"
    mvn appengine:run -e \
        -P eu,dev \
        -f "$root/emm-backend-webhost/pom.xml" $argv
end
