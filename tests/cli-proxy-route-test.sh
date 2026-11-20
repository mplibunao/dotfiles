#!/usr/bin/env bash
# Exercises cli-proxy-env-launch and claude-proxy-route against a fake
# launchctl, temporary homes and fixture keys. The live launchd session is
# never touched. Both scripts run under `env -i` with only PATH, HOME and the
# fake's variables, so the caller's real ANTHROPIC_AUTH_TOKEN and
# CLIPROXY_CLIENT_KEY cannot reach them or this output. Runs under bash 3.2
# (macOS /bin/bash) and later.
set -euo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
publisher="${repo_root}/scripts/cli-proxy-env-launch"
switch="${repo_root}/scripts/claude-proxy-route"
tmp="$(mktemp -d)"
trap 'chmod -R u+rwx "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT

fail() {
  printf 'fail: %s\n' "$1" >&2
  exit 1
}

file_mode() {
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

# Distinctive values, so a search of the built store for them means something.
# Each is the SHA-256 digest of a label, computed at runtime because secret
# scanners flag high-entropy literals assigned to key variables. The helper
# fails, naming the label and never the rejected value, unless the digest is 64
# lowercase hex characters.
fixture_key() {
  local digest
  if command -v sha256sum >/dev/null 2>&1; then
    digest="$(printf '%s' "$1" | sha256sum)" || fail "sha256sum failed"
  elif command -v shasum >/dev/null 2>&1; then
    digest="$(printf '%s' "$1" | shasum -a 256)" || fail "shasum -a 256 failed"
  else
    fail "fixture keys need sha256sum or shasum"
  fi
  digest="${digest%% *}"
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] \
    || fail "fixture key for '$1' is not a 64-character lowercase hex digest"
  printf '%s\n' "$digest"
}
key="$(fixture_key cli-proxy-route-test/key)"
old_key="$(fixture_key cli-proxy-route-test/old-key)"
rotated_key="$(fixture_key cli-proxy-route-test/rotated-key)"
[[ "$key" != "$old_key" && "$key" != "$rotated_key" && "$old_key" != "$rotated_key" ]] \
  || fail "the fixture keys are not distinct"
base_url="http://127.0.0.1:8317"
sys_path="/usr/bin:/bin:/usr/sbin:/sbin"
out="${tmp}/out"
mkdir -p "$out" "${tmp}/bin"

# The fake keeps its state in $FAKE_LC_DIR: env/NAME holds a published value
# and calls logs every invocation by operation and name, without values.
# runs, exit, pending and pid-polls stand in for the agent's launchd record.
# kickstart runs the publisher as the agent would, with agent-key as the key
# the Nix wrapper read and its stderr appended to the agent's error log. The
# first print after a kickstart still shows the job running, and print always
# includes the inherited environment, token and all, as the real one does.
fake="${tmp}/bin/launchctl"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
set -euo pipefail
dir="${FAKE_LC_DIR:?}"
mkdir -p "${dir}/env"
target="gui/$(id -u)/com.mp.cli-proxy-env"
op="${1:-}"
printf '%s %s\n' "$op" "${2:-}" >>"${dir}/calls"
case "$op" in
  setenv) printf '%s' "$3" >"${dir}/env/$2" ;;
  unsetenv) rm -f "${dir}/env/$2" ;;
  getenv)
    if [[ -f "${dir}/env/$2" ]]; then cat "${dir}/env/$2"; fi
    printf '\n'
    ;;
  kickstart)
    [[ "${2:-}" == "$target" ]] || exit 113
    state="${HOME}/.local/state/cli-proxy-api"
    rc=0
    (
      if [[ -f "${dir}/agent-key" ]]; then
        CPA_CLIENT_KEY="$(cat "${dir}/agent-key")"
        export CPA_CLIENT_KEY
      fi
      exec "$BASH" "$FAKE_LC_PUBLISHER" --route-file "${state}/claude-route" \
        --base-url "http://127.0.0.1:8317" --launchctl "$0"
    ) >>"${state}/cli-proxy-env.out.log" 2>>"${state}/cli-proxy-env.err.log" || rc=$?
    runs="$(cat "${dir}/runs" 2>/dev/null || printf 0)"
    printf '%s\n' "$((runs + 1))" >"${dir}/runs"
    printf '%s\n' "$rc" >"${dir}/pending"
    printf '1\n' >"${dir}/pid-polls"
    ;;
  print)
    [[ "${2:-}" == "$target" ]] || exit 113
    pid=""
    if [[ "$(cat "${dir}/pid-polls" 2>/dev/null || printf 0)" -gt 0 ]]; then
      pid=4242
      printf '0\n' >"${dir}/pid-polls"
    elif [[ -f "${dir}/pending" ]]; then
      mv "${dir}/pending" "${dir}/exit"
    fi
    printf '%s = {\n' "$target"
    if [[ -n "$pid" ]]; then printf '\tstate = running\n'; else printf '\tstate = not running\n'; fi
    printf '\n\tinherited environment = {\n'
    for f in "${dir}"/env/*; do
      if [[ -f "$f" ]]; then printf '\t\t%s => %s\n' "${f##*/}" "$(cat "$f")"; fi
    done
    printf '\t}\n\n'
    printf '\truns = %s\n' "$(cat "${dir}/runs" 2>/dev/null || printf 0)"
    if [[ -n "$pid" ]]; then printf '\tpid = %s\n' "$pid"; fi
    printf '\tlast exit code = %s\n' "$(cat "${dir}/exit" 2>/dev/null || printf '(never exited)')"
    printf '}\n'
    ;;
  *) exit 64 ;;
esac
EOF
} >"$fake"
chmod 0755 "$fake"

# run NAME HOME [VAR=VALUE...] CMD...: runs CMD under env -i and stores its
# stdout and stderr in $out/NAME.out and $out/NAME.err. Sets rc.
run() {
  local name="$1" home="$2"
  shift 2
  rc=0
  env -i PATH="$sys_path" HOME="$home" FAKE_LC_DIR="${home}/lc" FAKE_LC_PUBLISHER="$publisher" \
    "$@" >"${out}/${name}.out" 2>"${out}/${name}.err" || rc=$?
}

# run_publisher NAME HOME [VAR=VALUE...]: runs the publisher on HOME's route
# file.
run_publisher() {
  local name="$1" home="$2"
  shift 2
  run "$name" "$home" "$@" "$BASH" "$publisher" \
    --route-file "${home}/.local/state/cli-proxy-api/claude-route" \
    --base-url "$base_url" --launchctl "$fake"
}

# run_switch NAME HOME OPERATION: runs claude-proxy-route.
run_switch() {
  run "$1" "$2" "$BASH" "$switch" --launchctl "$fake" "$3"
}

# A fresh HOME whose launchd environment holds two variables the publisher
# must never touch.
new_home() {
  local home="${tmp}/$1"
  mkdir -p "${home}/.local/state/cli-proxy-api" "${home}/lc/env"
  printf 'sentinel' >"${home}/lc/env/OPENAI_BASE_URL"
  printf 'sentinel' >"${home}/lc/env/ANTHROPIC_API_KEY"
  printf '%s\n' "$home"
}

# The shared route-setting fixtures, plus an unreadable file and a setting
# whose directory cannot be searched.
set_route() {
  local file="$1/.local/state/cli-proxy-api/claude-route"
  rm -f "$file"
  case "$2" in
    missing) ;;
    on) printf 'on' >"$file" ;;
    off) printf 'off' >"$file" ;;
    off-newline) printf 'off\n' >"$file" ;;
    empty) : >"$file" ;;
    garbage) printf 'on\noff\n' >"$file" ;;
    unreadable)
      printf 'on\n' >"$file"
      chmod 000 "$file"
      ;;
    unsearchable)
      printf 'off\n' >"$file"
      chmod 000 "$(dirname "$file")"
      ;;
    *) fail "unknown fixture $2" ;;
  esac
}

# Seeds the variables an earlier publication of the route left behind.
seed_proxy_env() {
  printf '%s' "$2" >"$1/lc/env/CLIPROXY_CLIENT_KEY"
  printf '%s' "$2" >"$1/lc/env/ANTHROPIC_AUTH_TOKEN"
  printf '%s' "$base_url" >"$1/lc/env/ANTHROPIC_BASE_URL"
}

# Prints a published value for comparison; never pass it to fail.
published() {
  if [[ -f "$1/lc/env/$2" ]]; then cat "$1/lc/env/$2"; fi
}

is_unset() {
  [[ ! -e "$1/lc/env/$2" ]]
}

env_names() {
  local f names=""
  for f in "$1"/lc/env/*; do
    if [[ -e "$f" ]]; then names="${names}${f##*/} "; fi
  done
  printf '%s\n' "${names% }"
}

check_sentinels() {
  [[ "$(published "$1" OPENAI_BASE_URL)" == "sentinel" ]] || fail "$2: OPENAI_BASE_URL changed"
  [[ "$(published "$1" ANTHROPIC_API_KEY)" == "sentinel" ]] || fail "$2: ANTHROPIC_API_KEY changed"
}

# The route setting drives publication: missing and on publish all three
# variables, URL before token, and nothing else is touched.
for fixture in missing on; do
  home="$(new_home "pub-${fixture}")"
  set_route "$home" "$fixture"
  run_publisher "pub-${fixture}" "$home" CPA_CLIENT_KEY="$key"
  [[ $rc -eq 0 ]] || fail "${fixture}: publisher exited ${rc}"
  [[ "$(published "$home" CLIPROXY_CLIENT_KEY)" == "$key" ]] || fail "${fixture}: CLIPROXY_CLIENT_KEY not published"
  [[ "$(published "$home" ANTHROPIC_AUTH_TOKEN)" == "$key" ]] || fail "${fixture}: ANTHROPIC_AUTH_TOKEN not published"
  [[ "$(published "$home" ANTHROPIC_BASE_URL)" == "$base_url" ]] || fail "${fixture}: ANTHROPIC_BASE_URL not published"
  [[ "$(env_names "$home")" == "ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLIPROXY_CLIENT_KEY OPENAI_BASE_URL" ]] \
    || fail "${fixture}: publisher set another variable"
  check_sentinels "$home" "$fixture"
  if ! awk '/^setenv ANTHROPIC_BASE_URL$/ { u = NR } /^setenv ANTHROPIC_AUTH_TOKEN$/ { t = NR } END { exit !(u && t && u < t) }' "${home}/lc/calls"; then
    fail "${fixture}: ANTHROPIC_BASE_URL was not published before ANTHROPIC_AUTH_TOKEN"
  fi
done

# off unsets both Anthropic variables and keeps the shared client key,
# refreshed from the secrets file.
for fixture in off off-newline; do
  home="$(new_home "pub-${fixture}")"
  seed_proxy_env "$home" "$old_key"
  set_route "$home" "$fixture"
  run_publisher "pub-${fixture}" "$home" CPA_CLIENT_KEY="$key"
  [[ $rc -eq 0 ]] || fail "${fixture}: publisher exited ${rc}"
  is_unset "$home" ANTHROPIC_AUTH_TOKEN || fail "${fixture}: ANTHROPIC_AUTH_TOKEN still set"
  is_unset "$home" ANTHROPIC_BASE_URL || fail "${fixture}: ANTHROPIC_BASE_URL still set"
  [[ "$(published "$home" CLIPROXY_CLIENT_KEY)" == "$key" ]] || fail "${fixture}: CLIPROXY_CLIENT_KEY not refreshed"
  check_sentinels "$home" "$fixture"
done

# off without a readable key still clears Claude's route, keeps the key
# launchd already holds, and reports the failure.
home="$(new_home pub-off-nokey)"
seed_proxy_env "$home" "$old_key"
set_route "$home" off
run_publisher pub-off-nokey "$home"
[[ $rc -eq 1 ]] || fail "off without a key exited ${rc}, expected 1"
is_unset "$home" ANTHROPIC_AUTH_TOKEN || fail "off without a key left ANTHROPIC_AUTH_TOKEN set"
is_unset "$home" ANTHROPIC_BASE_URL || fail "off without a key left ANTHROPIC_BASE_URL set"
[[ "$(published "$home" CLIPROXY_CLIENT_KEY)" == "$old_key" ]] || fail "off without a key dropped the published client key"
grep -q 'not refreshed' "${out}/pub-off-nokey.err" || fail "off without a key did not say the key was not refreshed"

# A corrupt setting is not a route choice: the publisher exits 1 before any
# launchctl call, and status reports the error.
for fixture in empty garbage unreadable unsearchable; do
  if [[ "$fixture" == unsearchable || "$fixture" == unreadable ]] && [[ "$EUID" -eq 0 ]]; then continue; fi
  home="$(new_home "pub-${fixture}")"
  set_route "$home" "$fixture"
  run_publisher "pub-${fixture}" "$home" CPA_CLIENT_KEY="$key"
  [[ $rc -eq 1 ]] || fail "${fixture}: publisher exited ${rc}, expected 1"
  [[ ! -e "${home}/lc/calls" ]] || fail "${fixture}: publisher called launchctl"
  grep -q 'claude-route' "${out}/pub-${fixture}.err" || fail "${fixture}: publisher error does not name the file"
  run_switch "status-${fixture}" "$home" status
  [[ $rc -ne 0 ]] || fail "${fixture}: status exited 0"
  grep -q '^saved setting: *error: ' "${out}/status-${fixture}.out" || fail "${fixture}: status did not report the error"
  chmod 0700 "${home}/.local/state/cli-proxy-api"
done

# Watched apps. Fake pgrep, ps and osascript stand in for running processes:
# $FAKE_PROCS/<pid> holds a process name on its first line, that process's
# `ps -E` line on its second, and, for another user's process, its uid on a
# third. Like the real pgrep, the fake matches part of a name unless -x is
# given, and honours -u. Every osascript call's full argv is appended to
# $FAKE_ARGV, which sits under $out so the final key scan covers it. The run
# arguments of each shown notification are appended to $FAKE_NOTES, followed
# by a `--` line. FAKE_NOTIFY_FAIL makes osascript fail after logging argv.
watchbin="${tmp}/watchbin"
mkdir -p "$watchbin"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
uid=""
exact=0
while [[ $# -gt 1 ]]; do
  case "$1" in
    -u) uid="$2"; shift 2 ;;
    -x) exact=1; shift ;;
    *) shift ;;
  esac
done
found=1
for f in "${FAKE_PROCS:?}"/*; do
  [[ -f "$f" ]] || continue
  pname="$(sed -n 1p "$f")"
  if [[ $exact -eq 1 ]]; then
    [[ "$pname" == "$1" ]] || continue
  else
    [[ "$pname" == *"$1"* ]] || continue
  fi
  owner="$(sed -n 3p "$f")"
  if [[ -n "$uid" && -n "$owner" && "$owner" != "$uid" ]]; then continue; fi
  printf '%s\n' "${f##*/}"
  found=0
done
exit "$found"
EOF
} >"${watchbin}/pgrep"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
for pid; do :; done
sed -n 2p "${FAKE_PROCS:?}/${pid}"
EOF
} >"${watchbin}/ps"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
printf '%s\n' "$@" -- >>"${FAKE_ARGV:?}"
if [[ -n "${FAKE_NOTIFY_FAIL:-}" ]]; then exit 1; fi
while [[ $# -gt 0 && "$1" == "-e" ]]; do shift 2; done
printf '%s\n' "$@" -- >>"${FAKE_NOTES:?}"
EOF
} >"${watchbin}/osascript"
chmod 0755 "${watchbin}"/*

# add_proc HOME PID NAME [NAME=VALUE...]: a running process of this user that
# started with exactly these route variables.
add_proc() {
  local dir="$1/procs" pid="$2" name="$3"
  shift 3
  mkdir -p "$dir"
  printf '%s\n%s\n' "$name" "/Applications/Some App.app/Contents/MacOS/${name} PATH=/usr/bin:/bin $*" >"${dir}/${pid}"
}

# add_foreign_proc HOME PID NAME: another user's process, whose environment
# `ps -E` doesn't show.
add_foreign_proc() {
  mkdir -p "$1/procs"
  printf '%s\n%s\n%s\n' "$3" "/Applications/Some App.app/Contents/MacOS/$3" 99999 >"$1/procs/$2"
}

# run_watched NAME HOME [VAR=VALUE...]: runs the publisher on HOME's route
# file, watching RepoPrompt and kitty.
run_watched() {
  local name="$1" home="$2"
  shift 2
  run "$name" "$home" CPA_CLIENT_KEY="$key" PATH="${watchbin}:${sys_path}" \
    FAKE_PROCS="${home}/procs" FAKE_NOTES="${home}/notes" FAKE_ARGV="${out}/osascript-argv" "$@" \
    "$BASH" "$publisher" --route-file "${home}/.local/state/cli-proxy-api/claude-route" \
    --base-url "$base_url" --launchctl "$fake" \
    --watch-process RepoPrompt --watch-process kitty
}

proxy_vars=("ANTHROPIC_BASE_URL=${base_url}" "ANTHROPIC_AUTH_TOKEN=${key}" "CLIPROXY_CLIENT_KEY=${key}")

# On: one notification names the watched app that started without the route.
# The watched app that has it, the unwatched app and another user's copy of a
# watched app are left out.
home="$(new_home watch-on)"
set_route "$home" on
add_proc "$home" 101 RepoPrompt
add_proc "$home" 102 kitty "${proxy_vars[@]}"
add_proc "$home" 103 "Google Chrome"
add_foreign_proc "$home" 104 kitty
run_watched watch-on "$home"
[[ $rc -eq 0 ]] || fail "watch on: publisher exited ${rc}"
[[ "$(grep -c '^--$' "${home}/notes")" == 1 ]] || fail "watch on: expected exactly one notification"
grep -qx 'Claude proxy route is on' "${home}/notes" || fail "watch on: wrong notification title"
grep -qx 'Relaunch: RepoPrompt' "${home}/notes" || fail "watch on: the notification does not name only RepoPrompt"

# Once every watched app matches, nothing is shown. The stale RepoPromptDebug
# isn't watched in these runs, and a name match on RepoPrompt must not catch it.
rm -f "${home}/procs/101" "${home}/notes"
add_proc "$home" 105 RepoPromptDebug
run_watched watch-on-match "$home"
[[ $rc -eq 0 ]] || fail "watch on, all matching: publisher exited ${rc}"
[[ ! -e "${home}/notes" ]] || fail "watch on, all matching: a notification was shown"

# Off: the watched app still holding the proxy route is named, and the one
# that started with the route off is not.
home="$(new_home watch-off)"
seed_proxy_env "$home" "$key"
set_route "$home" off
add_proc "$home" 201 RepoPrompt "CLIPROXY_CLIENT_KEY=${key}"
add_proc "$home" 202 kitty "${proxy_vars[@]}"
run_watched watch-off "$home"
[[ $rc -eq 0 ]] || fail "watch off: publisher exited ${rc}"
[[ "$(grep -c '^--$' "${home}/notes")" == 1 ]] || fail "watch off: expected exactly one notification"
grep -qx 'Claude proxy route is off' "${home}/notes" || fail "watch off: wrong notification title"
grep -qx 'Relaunch: kitty' "${home}/notes" || fail "watch off: the notification does not name only kitty"

# A key rotated while the route is off: the app whose only difference is the
# old client key is named together with the one still holding the proxy route,
# in one notification.
home="$(new_home watch-rotated)"
seed_proxy_env "$home" "$old_key"
set_route "$home" off
add_proc "$home" 301 RepoPrompt "CLIPROXY_CLIENT_KEY=${old_key}"
add_proc "$home" 302 kitty "ANTHROPIC_BASE_URL=${base_url}" "ANTHROPIC_AUTH_TOKEN=${old_key}" "CLIPROXY_CLIENT_KEY=${old_key}"
run_watched watch-rotated "$home"
[[ $rc -eq 0 ]] || fail "watch rotated: publisher exited ${rc}"
[[ "$(grep -c '^--$' "${home}/notes")" == 1 ]] || fail "watch rotated: expected exactly one notification"
grep -qx 'Relaunch: RepoPrompt, kitty' "${home}/notes" || fail "watch rotated: the notification does not name both apps"

# A failing osascript leaves the publication and the exit status alone, and
# the apps are named on stderr instead.
home="$(new_home watch-notify-fails)"
set_route "$home" on
add_proc "$home" 401 RepoPrompt
run_watched watch-notify-fails "$home" FAKE_NOTIFY_FAIL=1
[[ $rc -eq 0 ]] || fail "failed notification: publisher exited ${rc}"
[[ "$(published "$home" ANTHROPIC_BASE_URL)" == "$base_url" ]] || fail "failed notification: the route was not published"
grep -q 'Quit and reopen: RepoPrompt\.' "${out}/watch-notify-fails.err" || fail "failed notification: stderr does not name the app"

# Every osascript call above was logged in full, so the final key scan of $out
# checks the AppleScript lines too.
[[ "$(grep -c '^--$' "${out}/osascript-argv")" == 4 ]] || fail "expected four logged osascript calls"

# claude-proxy-route end to end. The fake kickstart runs the real publisher.
home="$(new_home switch)"
switch_home="$home"
route_file="${home}/.local/state/cli-proxy-api/claude-route"
printf '%s' "$key" >"${home}/lc/agent-key"

run_switch status-initial "$home" status
[[ $rc -eq 1 ]] || fail "status with nothing published exited ${rc}, expected 1"
grep -q '^saved setting: *on (default' "${out}/status-initial.out" || fail "status did not report the default"
grep -q '^published route: *off$' "${out}/status-initial.out" || fail "status did not report the unpublished route"

run_switch off "$home" off
[[ $rc -eq 0 ]] || fail "claude-proxy-route off exited ${rc}"
printf 'off\n' | cmp -s - "$route_file" || fail "off did not save the setting"
[[ "$(file_mode "$route_file")" == "600" ]] || fail "the setting is not mode 0600"
is_unset "$home" ANTHROPIC_AUTH_TOKEN || fail "off left ANTHROPIC_AUTH_TOKEN set"
is_unset "$home" ANTHROPIC_BASE_URL || fail "off left ANTHROPIC_BASE_URL set"
[[ "$(published "$home" CLIPROXY_CLIENT_KEY)" == "$key" ]] || fail "off did not keep CLIPROXY_CLIENT_KEY"
grep -q '^published route: *off$' "${out}/off.out" || fail "off status did not report route off"
grep -q '^published client key: *present$' "${out}/off.out" || fail "off status did not report the key"

run_switch on "$home" on
[[ $rc -eq 0 ]] || fail "claude-proxy-route on exited ${rc}"
printf 'on\n' | cmp -s - "$route_file" || fail "on did not save the setting"
[[ "$(published "$home" ANTHROPIC_AUTH_TOKEN)" == "$key" ]] || fail "on did not publish ANTHROPIC_AUTH_TOKEN"
[[ "$(published "$home" ANTHROPIC_BASE_URL)" == "$base_url" ]] || fail "on did not publish ANTHROPIC_BASE_URL"
grep -q '^published route: *on$' "${out}/on.out" || fail "on status did not report route on"

# apply publishes a rotated key without changing the setting.
printf '%s' "$rotated_key" >"${home}/lc/agent-key"
setting_sum="$(cksum <"$route_file")"
run_switch apply "$home" apply
[[ $rc -eq 0 ]] || fail "claude-proxy-route apply exited ${rc}"
[[ "$(cksum <"$route_file")" == "$setting_sum" ]] || fail "apply changed the setting"
[[ "$(published "$home" CLIPROXY_CLIENT_KEY)" == "$rotated_key" ]] || fail "apply did not publish the rotated key"
[[ "$(published "$home" ANTHROPIC_AUTH_TOKEN)" == "$rotated_key" ]] || fail "apply did not publish the rotated token"

# A failed publication is reported and the setting is still saved, over a
# malformed one. The agent's last run exits 1, which launchd shows only once
# the job is no longer running.
rm -f "${home}/lc/agent-key"
set_route "$home" garbage
run_switch on-failed "$home" on
[[ $rc -eq 1 ]] || fail "on with a failing agent exited ${rc}, expected 1"
printf 'on\n' | cmp -s - "$route_file" || fail "on with a failing agent did not save the setting"
grep -q 'saved the setting (on), but com.mp.cli-proxy-env exited with code 1' "${out}/on-failed.err" \
  || fail "on with a failing agent did not report the failure"
grep -q 'client key could not be read' "${out}/on-failed.err" || fail "the failure did not show the agent's error log"
[[ "$(published "$home" ANTHROPIC_AUTH_TOKEN)" == "$rotated_key" ]] || fail "the failing agent changed the publication"

# No fixture key reaches any output, although the fake print output carries
# the published token, as the real one does.
FAKE_LC_DIR="${home}/lc" HOME="$home" "$fake" print "gui/$(id -u)/com.mp.cli-proxy-env" >"${tmp}/print.txt"
grep -qF "$rotated_key" "${tmp}/print.txt" || fail "the fake print output does not carry the token"
for k in "$key" "$old_key" "$rotated_key"; do
  if grep -rqF -- "$k" "$out" "${switch_home}/.local/state/cli-proxy-api"; then
    fail "a fixture key appeared in script output or the agent's logs"
  fi
done

printf 'ok\n'
