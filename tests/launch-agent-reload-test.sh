#!/usr/bin/env bash
# Runs the activation snippet from modules/cli-proxy/launch-agent.nix
# against a fake launchctl that behaves like launchd: bootstrap copies the
# plist into a "loaded definition" and never looks at the file again.
#
# Needs nix (to render the snippet) and awk. No launchd, no network.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'fail: %s\n' "$1" >&2
  exit 1
}

label="com.test.job"
launch_agents="${tmp}/LaunchAgents"
logs="${tmp}/logs"
fake_state="${tmp}/launchd"
fake_bin="${tmp}/bin"
calls="${fake_state}/calls"
mkdir -p "$launch_agents" "$logs" "$fake_state" "$fake_bin"
: >"$calls"

cat >"${fake_bin}/launchctl" <<'EOF'
#!/usr/bin/env bash
# Fake launchd. State lives in $FAKE_LAUNCHD.
state="${FAKE_LAUNCHD:?}"
cmd="$1"
shift
printf '%s %s\n' "$cmd" "$*" >>"${state}/calls"
case "$cmd" in
  print)
    [ -f "${state}/definition" ] || exit 113
    if [ -f "${state}/no-pid" ]; then
      printf '%s\n' '	last exit code = 1'
    else
      printf '%s\n' "	pid = $(cat "${state}/pid")"
      printf '%s\n' '	last exit code = 0'
    fi
    ;;
  bootstrap)
    if [ -f "${state}/definition" ]; then
      echo 'Bootstrap failed: 5: Input/output error' >&2
      exit 5
    fi
    cp -L "$2" "${state}/definition"
    rm -f "${state}/no-pid"
    echo $(($(cat "${state}/pid" 2>/dev/null || echo 100) + 1)) >"${state}/pid"
    ;;
  bootout)
    rm -f "${state}/definition"
    ;;
  kickstart) ;;
  *) exit 64 ;;
esac
EOF
cat >"${fake_bin}/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fake_bin}/launchctl" "${fake_bin}/sleep"

render() {
  # $1: store path the snippet should treat as the plist content.
  # Prints the snippet on stdout. Nix's stderr is shown only when nix eval fails.
  local snippet
  snippet="$(nix eval --impure --raw --expr "
    let
      lib = (builtins.getFlake \"git+file://${repo_root}\").inputs.nixpkgs.lib;
      loadAgent = import ${repo_root}/modules/cli-proxy/launch-agent.nix { inherit lib; };
    in
    loadAgent \"t\" {
      label = \"${label}\";
      plistPath = \"${launch_agents}/${label}.plist\";
      plistSource = \"$1\";
      logDir = \"${logs}\";
    }
  " 2>"${tmp}/render-err")" || {
    cat "${tmp}/render-err" >&2
    fail "nix eval could not render the snippet from launch-agent.nix"
  }
  printf '%s\n' "$snippet" |
    sed -e "s#/bin/launchctl#${fake_bin}/launchctl#g" -e "s#/usr/bin/awk#awk#g" ||
    fail "could not substitute the fake tools into the snippet"
}

install_plist() {
  # $1: version label. Point the on-disk plist at a new "generation".
  printf '<plist>%s</plist>\n' "$1" >"${tmp}/plist-$1"
  ln -sfn "${tmp}/plist-$1" "${launch_agents}/${label}.plist"
}

# prepare_switch VERSION: reset the call log and write the snippet for plist
# VERSION. Any failure stops the harness, so no case runs an old or partial
# snippet.
prepare_switch() {
  local rendered
  : >"$calls"
  # render runs in a command substitution, so its fail only ends that subshell.
  rendered="$(render "/nix/store/fake-$1.plist")" || exit 1
  printf '%s\n' "$rendered" >"${tmp}/snippet.sh" ||
    fail "could not write the activation snippet"
}

# run_switch [DRY_RUN_CMD]: run the prepared snippet. The caller decides where
# its stdout and stderr go.
run_switch() {
  PATH="${fake_bin}:${PATH}" FAKE_LAUNCHD="$fake_state" DRY_RUN_CMD="${1:-}" \
    bash "${tmp}/snippet.sh"
}

# switch VERSION [DRY_RUN_CMD]: one activation run with plist VERSION.
switch() {
  prepare_switch "$1"
  run_switch "${2:-}"
}

loaded_version() { sed -n 's#<plist>\(.*\)</plist>#\1#p' "${fake_state}/definition"; }
call_count() { grep -c "^$1 " "$calls" || true; }

# 1. First switch: job is not loaded, so it is bootstrapped.
install_plist v1
switch v1 >/dev/null
[[ "$(loaded_version)" == "v1" ]] || fail "first switch did not load v1"
[[ "$(call_count bootstrap)" == 1 ]] || fail "first switch should bootstrap once"
[[ "$(call_count bootout)" == 0 ]] || fail "first switch should not bootout"

# 2. Same plist again: nothing is touched.
switch v1 >/dev/null
[[ "$(call_count bootstrap)" == 0 && "$(call_count bootout)" == 0 ]] ||
  fail "unchanged plist must not reload the job"

# 3. Plist changes (new env vars, new Bun path, ...): the job must pick it up.
install_plist v2
switch v2 >"${tmp}/out"
[[ "$(loaded_version)" == "v2" ]] || fail "launchd still holds the old definition after a plist change"
[[ "$(call_count bootout)" == 1 && "$(call_count bootstrap)" == 1 ]] ||
  fail "plist change should bootout and bootstrap once"
grep -q 'reloading it' "${tmp}/out" || fail "reload was not announced"

# 4. The change is applied once. A second switch is a no-op.
switch v2 >/dev/null
[[ "$(call_count bootstrap)" == 0 && "$(call_count bootout)" == 0 ]] ||
  fail "applied plist change was reloaded again"

# 5. Dry run reports the reload and changes nothing.
install_plist v3
switch v3 echo >"${tmp}/out"
grep -q '^would reload:' "${tmp}/out" || fail "dry run did not report the reload"
[[ "$(loaded_version)" == "v2" ]] || fail "dry run changed the loaded definition"
[[ "$(call_count bootout)" == 0 && "$(call_count bootstrap)" == 0 ]] || fail "dry run called launchctl"

# 6. A loaded job with no record of what it was loaded from is reloaded, so a
#    definition applied by an older, non-reloading switch gets replaced.
rm -f "${logs}/${label}.loaded-plist"
switch v3 >/dev/null
[[ "$(loaded_version)" == "v3" ]] || fail "job with an unknown definition was not reloaded"

# 7. Same plist, but the job is not running: the switch fails and keeps the job.
touch "${fake_state}/no-pid"
# Prepare outside the `if`, where errexit is off, and capture stderr for the
# run only, so a render failure cannot pass for the expected error.
prepare_switch v3
if run_switch >/dev/null 2>"${tmp}/err"; then
  fail "a loaded job that is not running should fail the switch"
fi
grep -q 'loaded but not running' "${tmp}/err" || fail "missing not-running message"
[[ "$(call_count bootout)" == 0 ]] || fail "a crashed job with an unchanged plist should not be reloaded"

# 8. A plist change on a crash-looping job reloads it instead of failing.
install_plist v4
touch "${fake_state}/no-pid"
switch v4 >/dev/null
[[ "$(loaded_version)" == "v4" ]] || fail "plist change did not reload the crash-looping job"

printf 'ok\n'
