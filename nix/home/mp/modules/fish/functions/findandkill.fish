function findandkill --description "Find and kill process using a specific port"
    if test (count $argv) -eq 0
        echo "Usage: findandkill PORT"
        echo "Example: findandkill 3000"
        return 1
    end
    
    set -l port $argv[1]
    
    # Find the process ID using the port
    set -l pid (lsof -n -i4TCP:$port | grep LISTEN | awk '{ print $2 }')
    
    if test -z "$pid"
        echo "No process found on port $port"
        return 1
    end
    
    echo "Killing process $pid on port $port"
    kill -9 $pid
    
    if test $status -eq 0
        echo "✓ Process killed successfully"
    else
        echo "✗ Failed to kill process"
        return 1
    end
end