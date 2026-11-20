# launchd snippet shared by the CLIProxyAPI and dashboard modules.
#
# launchd copies a job's definition at bootstrap and never rereads the plist,
# so `kickstart -k` restarts the old definition. Home Manager's
# setupLaunchAgents only reloads `launchd.agents`; these plists are plain
# `home.file` entries.
#
# The loaded plist's store path (it changes with the content) is recorded in
# logDir, and only after the job has stayed up, so a failed load is retried by
# the next switch. A previous-generation comparison is not a substitute: it
# loses the change once one switch has swapped the symlink without reloading.
{ lib }:
prefix:
{
  label,
  plistPath,
  plistSource,
  logDir,
}:
''
  _${prefix}_domain="gui/$(id -u)"
  _${prefix}_target="$_${prefix}_domain/${label}"
  _${prefix}_stamp=${lib.escapeShellArg "${logDir}/${label}.loaded-plist"}
  _${prefix}_want=${lib.escapeShellArg (toString plistSource)}
  _${prefix}_state=""
  _${prefix}_read_state() {
    _${prefix}_state="$(/bin/launchctl print "$_${prefix}_target" 2>/dev/null || true)"
  }
  _${prefix}_field() {
    printf '%s\n' "$_${prefix}_state" \
      | /usr/bin/awk -F ' = ' -v key="$1" '$1 == "\t" key { print $2; exit }'
  }
  _${prefix}_fail_not_running() {
    echo "${label}: $1 (last exit code: $(_${prefix}_field 'last exit code'))." >&2
    echo "  Logs: ${logDir}/" >&2
    echo "  After fixing the cause: launchctl kickstart -k $_${prefix}_target" >&2
    exit 1
  }
  _${prefix}_bootstrap() {
    _${prefix}_tries=0
    until /bin/launchctl bootstrap "$_${prefix}_domain" ${lib.escapeShellArg plistPath}; do
      _${prefix}_tries=$((_${prefix}_tries + 1))
      if [ "$_${prefix}_tries" -ge 5 ]; then
        echo "${label}: launchctl bootstrap failed; the service is not loaded." >&2
        echo "  From the logged-in GUI session (not SSH):" >&2
        echo "    plutil -lint ${plistPath}" >&2
        echo "    launchctl bootstrap $_${prefix}_domain ${plistPath}" >&2
        exit 1
      fi
      sleep 1
    done
    _${prefix}_tries=0
    while _${prefix}_read_state && [ -z "$(_${prefix}_field pid)" ]; do
      _${prefix}_tries=$((_${prefix}_tries + 1))
      if [ "$_${prefix}_tries" -ge 20 ]; then
        _${prefix}_fail_not_running "was loaded but did not start within 10 seconds"
      fi
      sleep 0.5
    done
    _${prefix}_pid="$(_${prefix}_field pid)"
    sleep 3
    _${prefix}_read_state
    if [ "$(_${prefix}_field pid)" != "$_${prefix}_pid" ]; then
      _${prefix}_fail_not_running "started but exited within 3 seconds"
    fi
    printf '%s\n' "$_${prefix}_want" > "$_${prefix}_stamp"
  }

  _${prefix}_read_state
  if [ -z "$_${prefix}_state" ]; then
    if [ -n "$DRY_RUN_CMD" ]; then
      echo "would load: launchctl bootstrap $_${prefix}_domain ${plistPath}"
    else
      rm -f "$_${prefix}_stamp"
      _${prefix}_bootstrap
    fi
  elif [ "$(cat "$_${prefix}_stamp" 2>/dev/null || true)" != "$_${prefix}_want" ]; then
    if [ -n "$DRY_RUN_CMD" ]; then
      echo "would reload: launchctl bootout $_${prefix}_target, then bootstrap $_${prefix}_domain ${plistPath}"
    else
      echo "${label}: the loaded definition is not this generation's plist; reloading it."
      rm -f "$_${prefix}_stamp"
      /bin/launchctl bootout "$_${prefix}_target" || true
      # bootout returns before the job is gone. launchd waits out ExitTimeOut
      # (20s) before it kills a job that ignores SIGTERM.
      _${prefix}_tries=0
      while /bin/launchctl print "$_${prefix}_target" >/dev/null 2>&1; do
        _${prefix}_tries=$((_${prefix}_tries + 1))
        if [ "$_${prefix}_tries" -ge 120 ]; then
          echo "${label}: still loaded 60 seconds after launchctl bootout." >&2
          echo "  Run: launchctl bootout $_${prefix}_target" >&2
          echo "  Then: launchctl bootstrap $_${prefix}_domain ${plistPath}" >&2
          exit 1
        fi
        sleep 0.5
      done
      _${prefix}_bootstrap
    fi
  else
    _${prefix}_pid="$(_${prefix}_field pid)"
    if [ -z "$_${prefix}_pid" ]; then
      _${prefix}_fail_not_running "is loaded but not running"
    fi
  fi
''
