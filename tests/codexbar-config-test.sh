#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repo_root/scripts/codexbar-config"
raw_tmp="$(mktemp -d "${TMPDIR:-/tmp}/codexbar-config-test.XXXXXX")" || exit 1
tmp="$(cd "$raw_tmp" && pwd -P)" || exit 1
[[ -n "$tmp" && "$tmp" != / ]] || exit 1
trap 'rm -rf "$tmp"' EXIT

real_path="$PATH"
real_chmod="$(command -v chmod)"
real_date="$(command -v date)"
fake_bin="$tmp/bin"
control="$tmp/control"
test_home="$tmp/home"
race_driver="$tmp/codexbar-race-driver.py"
mkdir -p "$fake_bin" "$control" "$test_home"
export FAKE_CONTROL_DIR="$control"
export REAL_CHMOD="$real_chmod"
export REAL_DATE="$real_date"
export PATH="$fake_bin:$real_path"
export HOME="$test_home"

passes=0
failures=0
case_dir=""
config=""
profile_home=""
backup_dir=""
state_home=""
generated_bash_fake_names=(launchctl pgrep chmod date brew codexbar)

fail() {
  printf '  assertion failed: %s\n' "$*" >&2
  return 1
}

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label (expected '$expected', got '$actual')"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle')"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$label (unexpected '$needle')"
}

assert_fails() {
  local label="$1"
  shift
  if "$@"; then
    fail "$label unexpectedly succeeded"
    return 1
  fi
  return 0
}

run_scenario() {
  local name="$1"
  shift
  if ("$@"); then
    printf 'PASS: %s\n' "$name"
    passes=$((passes + 1))
  else
    printf 'FAIL: %s\n' "$name"
    failures=$((failures + 1))
  fi
}

write_fake_launchctl() {
  cat >"$fake_bin/launchctl" <<'EOF'
#!/usr/bin/env bash
set -u
if [[ "${1:-}" == getenv && -n "${2:-}" ]]; then
  file="${FAKE_CONTROL_DIR:?}/launchctl_${2}"
  [[ -f "$file" ]] && cat "$file"
  exit 0
fi
exit 1
EOF
}

write_fake_pgrep() {
  cat >"$fake_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
set -u
control="${FAKE_CONTROL_DIR:?}"
expected='/Applications/CodexBar[.]app/Contents/MacOS/CodexBar'
printf '%s\t%s\t%s\t%s\n' "$#" "${1:-}" "${2:-}" "${3:-}" >>"$control/pgrep.log"
if [[ $# -ne 3 || "$1" != -f || "$2" != -x || "$3" != "$expected" ]]; then
  printf 'invalid\n' >>"$control/pgrep-invalid.log"
  exit 2
fi
count=0
[[ -f "$control/pgrep-count" ]] && count="$(cat "$control/pgrep-count")"
count=$((count + 1))
printf '%s\n' "$count" >"$control/pgrep-count"
if [[ -f "$control/mutate-on-call" && "$(cat "$control/mutate-on-call")" == "$count" ]]; then
  cat "$control/external-config.json" >"${FAKE_CONFIG_PATH:?}"
  "$REAL_CHMOD" 600 "${FAKE_CONFIG_PATH:?}"
fi
if [[ -f "$control/app-start-on-call" && "$(cat "$control/app-start-on-call")" == "$count" ]]; then
  printf '4242\n'
  exit 0
fi
if [[ -f "$control/probe-error-on-call" && "$(cat "$control/probe-error-on-call")" == "$count" ]]; then
  exit 2
fi
if [[ -f "$control/running" ]]; then
  printf '4242\n'
  exit 0
fi
exit 1
EOF
}

write_fake_chmod() {
  cat >"$fake_bin/chmod" <<'EOF'
#!/usr/bin/env bash
set -u
control="${FAKE_CONTROL_DIR:?}"
last="${!#}"
if [[ "$last" == */codexbar-config/lock && -f "$control/pause-lock-init" ]]; then
  : >"$control/lock-init-paused"
  while [[ ! -f "$control/lock-init-release" ]]; do sleep 0.02; done
fi
if [[ "$last" == */codexbar-config/lock && -f "$control/fail-lock-chmod" ]]; then
  exit 1
fi
if [[ "$last" == */codexbar-config/lock && -f "$control/read-only-lock" ]]; then
  "$REAL_CHMOD" 500 "$last"
  exit 0
fi
if [[ "$last" == */codexbar-config/lock/pid && -f "$control/fail-pid-chmod" ]]; then
  exit 1
fi
if [[ "$last" == *.codexbar-snapshot.* && -f "$control/mutate-on-snapshot-chmod" ]]; then
  "$REAL_CHMOD" "$@" || exit $?
  cat "$control/external-config.json" >"${FAKE_CONFIG_PATH:?}"
  "$REAL_CHMOD" 600 "${FAKE_CONFIG_PATH:?}"
  exit 0
fi
if [[ "$last" == *.codexbar-restore.* && -f "$control/pause-restore-chmod" ]]; then
  : >"$control/restore-paused"
  while [[ ! -f "$control/restore-release" ]]; do sleep 0.02; done
fi
exec "$REAL_CHMOD" "$@"
EOF
}

write_fake_date() {
  cat >"$fake_bin/date" <<'EOF'
#!/usr/bin/env bash
set -u
if [[ -f "${FAKE_CONTROL_DIR:?}/fixed-date" && " $* " == *" -u "* ]]; then
  printf '20260101T000000Z\n'
  exit 0
fi
exec "$REAL_DATE" "$@"
EOF
}

write_fake_brew() {
  cat >"$fake_bin/brew" <<'EOF'
#!/usr/bin/env bash
set -u
case " $* " in
  *" list --versions --cask codexbar "*) printf 'codexbar 0.17.0\n' ;;
  *" info --json=v2 --cask codexbar "*) printf '{"casks":[{"token":"codexbar","version":"0.45.2"}]}\n' ;;
  *) exit 1 ;;
esac
EOF
}

write_fake_codexbar() {
  cat >"$fake_bin/codexbar" <<'EOF'
#!/usr/bin/env bash
set -u
control="${FAKE_CONTROL_DIR:?}"
if [[ "${1:-}" == --version ]]; then
  printf 'CodexBar 0.54.0\n'
  exit 0
fi
if [[ "${1:-}" == config && "${2:-}" == validate ]]; then
  printf 'validate\n' >>"$control/validate.log"
  printf '%s\n' "${CODEXBAR_CONFIG:?}" >>"$control/validate-targets.log"
  if [[ -f "$control/validate-sleep" ]]; then
    sleep "$(cat "$control/validate-sleep")"
  fi
  if [[ -f "$control/signal-window" ]]; then
    : >"$control/validator-started"
    while [[ ! -f "$control/validator-release" ]]; do sleep 0.02; done
  fi
  if [[ -f "$control/noop-validation-window" ]]; then
    : >"$control/noop-validator-started"
    while [[ ! -f "$control/noop-validator-release" ]]; do sleep 0.02; done
  fi
  if [[ -f "$control/reject-all" ]]; then
    exit 1
  fi
  if [[ -f "$control/reject-unknown" ]] \
    && jq -e '.providers[]? | select(.id? == "codex") | has("codexProfileHomePathz")' \
      "${CODEXBAR_CONFIG:?}" >/dev/null 2>&1; then
    exit 1
  fi
  if [[ -f "$control/reject-managed" ]] \
    && jq -e '.providers[]? | select(.id? == "codex") | has("codexProfileHomePaths")' \
      "${CODEXBAR_CONFIG:?}" >/dev/null 2>&1; then
    exit 1
  fi
  jq -e 'type == "object" and (.providers | type == "array")' \
    "${CODEXBAR_CONFIG:?}" >/dev/null 2>&1
  exit $?
fi
exit 2
EOF
}

setup_fake_commands() {
  local fake_name
  write_fake_launchctl
  write_fake_pgrep
  write_fake_chmod
  write_fake_date
  write_fake_brew
  write_fake_codexbar
  for fake_name in "${generated_bash_fake_names[@]}"; do
    chmod +x "$fake_bin/$fake_name"
  done
}

write_race_driver() {
  cat >"$race_driver" <<'PY'
#!/usr/bin/env python3
import argparse
import glob
import json
import os
import shutil
import signal
import subprocess
import sys
import time


class RaceRunner:
    def __init__(self, args):
        self.args = args
        self.process = None
        self.output_stream = None

    def launch(self, operation):
        env = os.environ.copy()
        env.update({
            "HOME": os.environ["HOME"],
            "XDG_STATE_HOME": self.args.xdg_state_home,
            "CODEXBAR_CONFIG_TEST_MODE": "synthetic-fixture",
            "CODEXBAR_CONFIG_TEST_STATE_ROOT": os.path.join(self.args.state_dir, "codexbar-config"),
            "FAKE_CONTROL_DIR": self.args.control_dir,
            "FAKE_CONFIG_PATH": self.args.config,
            "PATH": self.args.path,
        })
        command = [
            "bash",
            self.args.helper,
            operation,
            "--config",
            self.args.config,
            "--profile-home",
            self.args.profile_home,
        ]
        if operation != "check":
            command += ["--backup-dir", self.args.backup_dir]
        self.output_stream = open(self.args.output, "wb")
        self.process = subprocess.Popen(
            command,
            env=env,
            stdout=self.output_stream,
            stderr=subprocess.STDOUT,
        )

    def marker_path(self, name):
        return os.path.join(self.args.control_dir, name)

    def wait_for_marker(self, name, window):
        marker = self.marker_path(name)
        deadline = time.monotonic() + 10
        while not os.path.exists(marker) and time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise RuntimeError(
                    f"helper exited before {window}: {self.process.returncode}"
                )
            time.sleep(0.02)
        if not os.path.exists(marker):
            raise RuntimeError(f"helper never reached {window}")

    def release(self, name):
        open(self.marker_path(name), "a").close()

    def wait_for_status(self):
        status = self.process.wait(timeout=10)
        self.close_output()
        return status

    def close_output(self):
        if self.output_stream is not None:
            self.output_stream.close()
            self.output_stream = None

    def cleanup(self):
        for marker in (
            "validator-release",
            "noop-validator-release",
            "restore-release",
        ):
            try:
                self.release(marker)
            except OSError:
                pass
        if self.process is not None and self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        self.close_output()


def signal_rollback(runner, args):
    runner.launch("reconcile")
    runner.wait_for_marker("validator-started", "validation window")
    with open(args.config, encoding="utf-8") as handle:
        document = json.load(handle)
    codex = [
        provider for provider in document["providers"] if provider.get("id") == "codex"
    ][0]
    if codex.get("codexProfileHomePaths") != [args.profile_home]:
        raise RuntimeError("replacement was not visible in validation window")
    runner.process.send_signal(getattr(signal, "SIG" + args.signal_name))
    runner.release("validator-release")
    return runner.wait_for_status()


def noop_snapshot_race(runner, args):
    runner.launch(args.operation)
    runner.wait_for_marker("noop-validator-started", "no-op validation window")
    shutil.copyfile(args.external_config, args.config)
    os.chmod(args.config, 0o600)
    runner.release("noop-validator-release")
    return runner.wait_for_status()


def post_commit_rewrite(runner, args):
    runner.launch("reconcile")
    runner.wait_for_marker("validator-started", "post-commit validation window")
    shutil.copyfile(args.external_config, args.config)
    os.chmod(args.config, 0o600)
    runner.release("validator-release")
    return runner.wait_for_status()


def post_commit_app_start(runner, args):
    runner.launch("reconcile")
    runner.wait_for_marker("validator-started", "post-commit validation window")
    runner.release("running")
    runner.release("validator-release")
    return runner.wait_for_status()


def corrupted_backup_restore(runner, args):
    runner.launch("reconcile")
    runner.wait_for_marker("validator-started", "rollback validation window")
    candidates = glob.glob(os.path.join(args.backup_dir, "config.json.*.bak.*"))
    if len(candidates) != 1:
        raise RuntimeError(f"expected one retained backup, found {len(candidates)}")
    with open(candidates[0], "wb") as handle:
        handle.write(b"CORRUPTED_RETAINED_BACKUP\n")
    os.chmod(candidates[0], 0o600)
    runner.release("validator-release")
    return runner.wait_for_status()


def interrupted_restore(runner, args):
    runner.launch("reconcile")
    runner.wait_for_marker("validator-started", "validation window")
    runner.process.send_signal(signal.SIGTERM)
    runner.release("validator-release")
    runner.wait_for_marker("restore-paused", "restoration pause")
    runner.process.send_signal(signal.SIGHUP)
    runner.release("restore-release")
    return runner.wait_for_status()


def add_common_arguments(parser):
    parser.add_argument("--helper", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("--profile-home", required=True)
    parser.add_argument("--backup-dir", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--control-dir", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--path", required=True)
    parser.add_argument("--xdg-state-home", required=True)


def parse_args():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="race_operation", required=True)

    signal_parser = subparsers.add_parser("signal-rollback")
    add_common_arguments(signal_parser)
    signal_parser.add_argument("--signal-name", choices=("HUP", "INT", "TERM"), required=True)
    signal_parser.set_defaults(handler=signal_rollback)

    noop_parser = subparsers.add_parser("noop-snapshot-race")
    add_common_arguments(noop_parser)
    noop_parser.add_argument(
        "--operation",
        choices=("check", "reconcile", "remove-managed-profile"),
        required=True,
    )
    noop_parser.add_argument("--external-config", required=True)
    noop_parser.set_defaults(handler=noop_snapshot_race)

    post_commit_rewrite_parser = subparsers.add_parser("post-commit-rewrite")
    add_common_arguments(post_commit_rewrite_parser)
    post_commit_rewrite_parser.add_argument("--external-config", required=True)
    post_commit_rewrite_parser.set_defaults(handler=post_commit_rewrite)

    post_commit_app_parser = subparsers.add_parser("post-commit-app-start")
    add_common_arguments(post_commit_app_parser)
    post_commit_app_parser.set_defaults(handler=post_commit_app_start)

    corrupted_parser = subparsers.add_parser("corrupted-backup-restore")
    add_common_arguments(corrupted_parser)
    corrupted_parser.set_defaults(handler=corrupted_backup_restore)

    interrupted_parser = subparsers.add_parser("interrupted-restore")
    add_common_arguments(interrupted_parser)
    interrupted_parser.set_defaults(handler=interrupted_restore)

    return parser.parse_args()


def main():
    args = parse_args()
    runner = RaceRunner(args)
    try:
        status = args.handler(runner, args)
    except Exception as error:
        runner.cleanup()
        print(f"race driver: {error}", file=sys.stderr)
        return 1
    print(status)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
}

reset_case() {
  local name="$1"
  case_dir="$tmp/cases/$name"
  rm -rf "$case_dir" "$control"/* "$HOME/.config"
  mkdir -p "$case_dir" "$control"
  config="$case_dir/config.json"
  profile_home="$case_dir/RepoPrompt home"
  backup_dir="$case_dir/backups"
  state_home="$case_dir/state"
  mkdir -p "$profile_home"
}

write_base_config() {
  cat >"$config" <<'EOF'
{
  "version": 1,
  "hugeInteger": 900719925474099312345,
  "preciseDecimal": 0.12345678901234567890123456789,
  "privateMarker": "DO_NOT_PRINT_PRIVATE_VALUE",
  "providers": [
    {"id": "other", "enabled": false, "nested": {"preserve": [3, 2, 1]}},
    {"id": "codex", "enabled": true, "unrelated": "keep-me"}
  ]
}
EOF
  chmod 600 "$config"
}

write_managed_config() {
  cat >"$config" <<EOF
{
  "version": 1,
  "privateMarker": "DO_NOT_PRINT_PRIVATE_VALUE",
  "providers": [
    {"id": "codex", "enabled": true, "codexProfileHomePaths": ["$profile_home"]},
    {"id": "other", "value": 7}
  ]
}
EOF
  chmod 600 "$config"
}

run_helper() {
  local output_file="$1"
  shift
  HOME="$HOME" XDG_STATE_HOME="${TEST_XDG_STATE_HOME:-$state_home/ambient}" \
    CODEXBAR_CONFIG_TEST_MODE=synthetic-fixture \
    CODEXBAR_CONFIG_TEST_STATE_ROOT="$state_home/codexbar-config" \
    FAKE_CONTROL_DIR="$control" FAKE_CONFIG_PATH="$config" PATH="$PATH" \
    bash "$helper" "$@" >"$output_file" 2>&1
}

backup_count() {
  if [[ ! -d "$backup_dir" ]]; then
    printf '0\n'
    return
  fi
  find "$backup_dir" -type f -name '*.bak*' | wc -l | tr -d ' '
}

backup_from_output() {
  sed -n 's/^backup=//p' "$1" | tail -n 1
}

assert_mode_600() {
  python3 - "$1" <<'PY'
import os
import stat
import sys
mode = stat.S_IMODE(os.stat(sys.argv[1]).st_mode)
if mode != 0o600:
    raise SystemExit(f"expected mode 0600, got {mode:04o}")
PY
}

assert_semantic_transform() {
  local before="$1" after="$2" action="$3"
  python3 - "$before" "$after" "$action" "$profile_home" <<'PY'
import copy
import decimal
import json
import sys

before_path, after_path, action, managed = sys.argv[1:]

def load(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle, parse_float=decimal.Decimal, parse_int=int)

before = load(before_path)
after = load(after_path)
expected = copy.deepcopy(before)
codex = [provider for provider in expected["providers"] if provider.get("id") == "codex"][0]
paths = codex.get("codexProfileHomePaths", [])
if action == "reconcile":
    output = []
    seen = False
    for path in paths:
        if path == managed:
            if seen:
                continue
            seen = True
        output.append(path)
    if not seen:
        output.append(managed)
    codex["codexProfileHomePaths"] = output
elif action == "remove":
    output = [path for path in paths if path != managed]
    if output:
        codex["codexProfileHomePaths"] = output
    else:
        codex.pop("codexProfileHomePaths", None)
else:
    raise SystemExit(f"unknown action: {action}")

if after != expected:
    raise SystemExit(f"semantic mismatch\nexpected={expected!r}\nactual={after!r}")
PY
}

scenario_reconcile_check_idempotence() {
  local before first_after output backup backups_before
  reset_case normal
  config="$HOME/.config/codexbar/config.json"
  mkdir -p "$(dirname "$config")"
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  output="$case_dir/reconcile.out"

  run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" \
    || { cat "$output" >&2; return 1; }
  assert_contains "$(cat "$output")" 'operation=reconcile status=changed' 'normal reconcile status' || return 1
  assert_not_contains "$(cat "$output")" 'default XDG location contains' 'canonical XDG target is not shadowed' || return 1
  assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'normal output privacy' || return 1
  assert_contains "$(cat "$output")" 'cli=0.54.0' 'version summary' || return 1
  assert_semantic_transform "$before" "$config" reconcile || return 1
  assert_mode_600 "$config" || return 1
  backup="$(backup_from_output "$output")"
  [[ -f "$backup" ]] || fail 'normal reconcile backup exists' || return 1
  cmp -s "$before" "$backup" || fail 'backup is byte-for-byte original' || return 1
  assert_mode_600 "$backup" || return 1

  first_after="$case_dir/first-after.json"
  cp "$config" "$first_after"
  backups_before="$(backup_count)"
  run_helper "$case_dir/idempotent.out" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" \
    || return 1
  assert_contains "$(cat "$case_dir/idempotent.out")" 'operation=reconcile status=unchanged' 'idempotent status' || return 1
  cmp -s "$first_after" "$config" || fail 'idempotent reconcile leaves bytes untouched' || return 1
  assert_eq "$backups_before" "$(backup_count)" 'idempotent reconcile creates no backup' || return 1

  run_helper "$case_dir/check.out" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$case_dir/check.out")" 'operation=check status=unchanged' 'satisfied check status' || return 1

  cp "$before" "$config"
  chmod 600 "$config"
  run_helper "$case_dir/check-needed.out" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$case_dir/check-needed.out")" 'operation=check status=change-required' 'unsatisfied check status' || return 1
  assert_eq "$(file_hash_for_test "$before")" "$(file_hash_for_test "$config")" 'check is config-read-only' || return 1
}

file_hash_for_test() {
  python3 - "$1" <<'PY'
import hashlib
import sys
with open(sys.argv[1], "rb") as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
}

scenario_duplicate_and_removal() {
  local before output
  reset_case duplicates
  cat >"$config" <<EOF
{
  "version": 1,
  "privateMarker": "DO_NOT_PRINT_PRIVATE_VALUE",
  "providers": [
    {"id":"codex","codexProfileHomePaths":["$profile_home","/other/a","$profile_home","/other/a"]},
    {"id":"other","data":{"x":1}}
  ]
}
EOF
  chmod 600 "$config"
  before="$case_dir/before.json"
  cp "$config" "$before"
  output="$case_dir/reconcile.out"
  run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_semantic_transform "$before" "$config" reconcile || return 1
  assert_eq "1" "$(jq --arg path "$profile_home" '[.providers[] | select(.id == "codex") | .codexProfileHomePaths[] | select(. == $path)] | length' "$config")" 'managed duplicate collapsed' || return 1
  assert_eq "2" "$(jq '[.providers[] | select(.id == "codex") | .codexProfileHomePaths[] | select(. == "/other/a")] | length' "$config")" 'unrelated duplicate preserved' || return 1

  cp "$config" "$before"
  run_helper "$case_dir/remove.out" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_semantic_transform "$before" "$config" remove || return 1
  assert_eq '["/other/a","/other/a"]' "$(jq -c '.providers[] | select(.id == "codex") | .codexProfileHomePaths' "$config")" 'removal preserves unrelated order and duplicates' || return 1

  write_managed_config
  cp "$config" "$before"
  run_helper "$case_dir/remove-only.out" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_semantic_transform "$before" "$config" remove || return 1
  jq -e '.providers[] | select(.id == "codex") | has("codexProfileHomePaths") | not' "$config" >/dev/null \
    || fail 'last managed path removal deletes array key' || return 1

  cp "$config" "$before"
  local count_before="$(backup_count)"
  run_helper "$case_dir/remove-noop.out" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_contains "$(cat "$case_dir/remove-noop.out")" 'status=unchanged' 'removal no-op status' || return 1
  cmp -s "$before" "$config" || fail 'removal no-op leaves bytes untouched' || return 1
  assert_eq "$count_before" "$(backup_count)" 'removal no-op creates no backup' || return 1
}

scenario_malformed_shapes() {
  local index=0 json before op output
  local fixtures=(
    'not-json'
    '[]'
    '{}'
    '{"providers":{}}'
    '{"providers":[7,{"id":"codex"}]}'
    '{"providers":[{"id":"other"}]}'
    '{"providers":[{"id":"codex"},{"id":"codex"}]}'
    '{"providers":[{"id":"codex","codexProfileHomePaths":null}]}'
    '{"providers":[{"id":"codex","codexProfileHomePaths":"/bad"}]}'
    '{"providers":[{"id":"codex","codexProfileHomePaths":[7]}]}'
  )

  reset_case malformed
  for json in "${fixtures[@]}"; do
    index=$((index + 1))
    printf '%s\n' "$json" >"$config"
    chmod 600 "$config"
    before="$case_dir/before-$index"
    cp "$config" "$before"
    for op in check reconcile; do
      output="$case_dir/$op-$index.out"
      if [[ "$op" == check ]]; then
        assert_fails "malformed $index check" run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
      else
        assert_fails "malformed $index reconcile" run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
      fi
      cmp -s "$before" "$config" || fail "malformed $index was modified by $op" || return 1
      assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' "malformed $index output privacy" || return 1
    done
  done
  assert_eq 0 "$(backup_count)" 'malformed fixtures create no backups'
}

scenario_precedence_shadowing() {
  local before canonical_before output xdg
  reset_case shadow
  write_managed_config
  before="$case_dir/before.json"
  cp "$config" "$before"

  printf '/tmp/other-config.json\n' >"$control/launchctl_CODEXBAR_CONFIG"
  output="$case_dir/config-env.out"
  assert_fails 'launchd config override' run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$output")" 'CODEXBAR_CONFIG shadows' 'launchd config diagnostic' || return 1
  rm "$control/launchctl_CODEXBAR_CONFIG"

  xdg="$case_dir/launchd-xdg"
  mkdir -p "$xdg/codexbar"
  printf '{}\n' >"$xdg/codexbar/config.json"
  printf '%s\n' "$xdg" >"$control/launchctl_XDG_CONFIG_HOME"
  assert_fails 'launchd XDG config override' run_helper "$case_dir/xdg-env.out" check --config "$config" --profile-home "$profile_home" || return 1
  rm "$control/launchctl_XDG_CONFIG_HOME"

  mkdir -p "$HOME/.config/codexbar"
  printf '{}\n' >"$HOME/.config/codexbar/config.json"
  assert_fails 'default XDG config override' run_helper "$case_dir/default-xdg.out" check --config "$config" --profile-home "$profile_home" || return 1
  rm -rf "$HOME/.config"

  cmp -s "$before" "$config" || fail 'shadow checks modified target' || return 1
  assert_eq 0 "$(backup_count)" 'shadow checks create no backups' || return 1

  config="$HOME/.config/codexbar/config.json"
  mkdir -p "$(dirname "$config")"
  write_managed_config
  canonical_before="$case_dir/canonical-before.json"
  cp "$config" "$canonical_before"
  printf '%s\n' "$HOME/.config" >"$control/launchctl_XDG_CONFIG_HOME"
  output="$case_dir/same-xdg.out"
  run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$output")" 'operation=check status=unchanged' 'same-target launchd XDG status' || return 1
  assert_not_contains "$(cat "$output")" 'higher-precedence CodexBar config' 'same-target launchd XDG is not shadowed' || return 1
  assert_not_contains "$(cat "$output")" 'default XDG location contains' 'canonical default XDG target is not shadowed' || return 1
  assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'same-target launchd XDG output privacy' || return 1
  cmp -s "$canonical_before" "$config" || fail 'same-target launchd XDG check modified target' || return 1
  assert_eq 0 "$(backup_count)" 'same-target launchd XDG check creates no backup' || return 1
  rm "$control/launchctl_XDG_CONFIG_HOME"
}

scenario_running_and_deferral() {
  local before output
  reset_case running
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  : >"$control/running"

  output="$case_dir/direct.out"
  assert_fails 'direct reconcile while running' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_contains "$(cat "$output")" 'CodexBar is running' 'running abort diagnostic' || return 1
  cmp -s "$before" "$config" || fail 'running abort modified config' || return 1

  output="$case_dir/defer.out"
  run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" --defer-if-running || return 1
  assert_contains "$(cat "$output")" 'operation=reconcile status=deferred' 'deferred status' || return 1
  assert_contains "$(cat "$output")" 'supervised-command=' 'deferred supervised command' || return 1
  assert_not_contains "$(cat "$output")" '--defer-if-running' 'supervised command is non-deferring' || return 1
  cmp -s "$before" "$config" || fail 'deferred reconcile modified config' || return 1
  assert_eq 0 "$(backup_count)" 'running paths create no backups' || return 1

  write_managed_config
  cp "$config" "$before"
  run_helper "$case_dir/unchanged.out" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_contains "$(cat "$case_dir/unchanged.out")" 'status=unchanged' 'running no-op allowed' || return 1
  cmp -s "$before" "$config" || fail 'running no-op modified config' || return 1

  assert_fails 'removal while running' run_helper "$case_dir/remove.out" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
}

scenario_locking_and_permissions() {
  local lock output first_pid attempts real_config
  reset_case locking
  write_managed_config
  lock="$state_home/codexbar-config/lock"
  mkdir -p "$lock"
  printf '%s\n' "$$" >"$lock/pid"
  assert_fails 'live lock' run_helper "$case_dir/live-lock.out" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$case_dir/live-lock.out")" 'holds the lock' 'live lock diagnostic' || return 1

  printf '99999999\n' >"$lock/pid"
  run_helper "$case_dir/stale-lock.out" check --config "$config" --profile-home "$profile_home" || return 1
  [[ ! -e "$lock" ]] || fail 'stale lock was not cleaned after check' || return 1

  printf '2\n' >"$control/validate-sleep"
  run_helper "$case_dir/first.out" check --config "$config" --profile-home "$profile_home" &
  first_pid=$!
  attempts=0
  while [[ ! -f "$lock/pid" && $attempts -lt 100 ]]; do
    sleep 0.02
    attempts=$((attempts + 1))
  done
  [[ -f "$lock/pid" ]] || { kill "$first_pid" 2>/dev/null || true; fail 'parallel helper never acquired lock'; return 1; }
  assert_fails 'parallel lock contention' run_helper "$case_dir/second.out" check --config "$config" --profile-home "$profile_home" || return 1
  wait "$first_pid" || return 1
  rm "$control/validate-sleep"

  real_config="$case_dir/real.json"
  cp "$config" "$real_config"
  rm "$config"
  ln -s "$real_config" "$config"
  assert_fails 'symlink config' run_helper "$case_dir/symlink.out" check --config "$config" --profile-home "$profile_home" || return 1
  rm "$config"
  cp "$real_config" "$config"
  chmod 400 "$config"
  assert_fails 'unwritable config' run_helper "$case_dir/unwritable.out" check --config "$config" --profile-home "$profile_home" || return 1
  chmod 600 "$config"

  rm -rf "$backup_dir"
  mkdir "$case_dir/backup-target"
  ln -s "$case_dir/backup-target" "$backup_dir"
  cp "$config" "$real_config"
  jq '(.providers[] | select(.id == "codex")) |= del(.codexProfileHomePaths)' "$config" >"$case_dir/missing.json"
  mv "$case_dir/missing.json" "$config"
  chmod 600 "$config"
  assert_fails 'symlink backup directory' run_helper "$case_dir/backup-symlink.out" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_eq 0 "$(find "$case_dir/backup-target" -type f | wc -l | tr -d ' ')" 'symlink backup target untouched'
}

scenario_cli_unknown_and_rollback() {
  local before output backup
  reset_case cli
  write_base_config
  jq '(.providers[] | select(.id == "codex")).codexProfileHomePathz = ["DO_NOT_PRINT_PRIVATE_VALUE"]' "$config" >"$case_dir/unknown.json"
  mv "$case_dir/unknown.json" "$config"
  chmod 600 "$config"
  before="$case_dir/before-unknown.json"
  cp "$config" "$before"

  run_helper "$case_dir/unknown-accepted.out" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_semantic_transform "$before" "$config" reconcile || return 1
  jq -e '.providers[] | select(.id == "codex") | has("codexProfileHomePathz")' "$config" >/dev/null \
    || fail 'CLI-accepted unknown key was not preserved' || return 1

  : >"$control/reject-unknown"
  assert_fails 'CLI rejects unknown key' run_helper "$case_dir/unknown-rejected.out" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$case_dir/unknown-rejected.out")" 'CodexBar CLI rejected' 'unknown-key rejection diagnostic' || return 1
  assert_not_contains "$(cat "$case_dir/unknown-rejected.out")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'unknown-key output privacy' || return 1
  rm "$control/reject-unknown"

  reset_case rollback
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  : >"$control/reject-managed"
  output="$case_dir/rollback.out"
  assert_fails 'post-write CLI rejection' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  cmp -s "$before" "$config" || fail 'CLI rejection did not restore original bytes' || return 1
  assert_mode_600 "$config" || return 1
  backup="$(sed -n 's/.*backup=//p' "$output" | tail -n 1)"
  [[ -f "$backup" ]] || fail 'rollback backup is retained' || return 1
  cmp -s "$before" "$backup" || fail 'rollback backup differs from original' || return 1
  assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'rollback output privacy' || return 1
}

scenario_invalid_inputs_and_missing_target() {
  local output before
  reset_case inputs
  write_managed_config
  before="$case_dir/before.json"
  cp "$config" "$before"

  assert_fails 'relative profile' run_helper "$case_dir/relative.out" check --config "$config" --profile-home relative/path || return 1
  assert_fails 'tilde profile' run_helper "$case_dir/tilde.out" check --config "$config" --profile-home '/tmp/~profile' || return 1
  assert_fails 'dot-dot profile' run_helper "$case_dir/dotdot.out" check --config "$config" --profile-home '/tmp/a/../b' || return 1
  assert_fails 'empty profile' run_helper "$case_dir/empty.out" check --config "$config" --profile-home '' || return 1
  assert_fails 'check backup argument' run_helper "$case_dir/check-backup.out" check --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_fails 'remove deferral argument' run_helper "$case_dir/remove-defer.out" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" --defer-if-running || return 1
  cmp -s "$before" "$config" || fail 'invalid inputs modified config' || return 1

  rm "$config"
  output="$case_dir/missing.out"
  assert_fails 'missing target' run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$output")" 'launch CodexBar once' 'missing target guidance'
}

scenario_concurrent_change_exclusion() {
  local before external output

  reset_case snapshot-writer
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  external="$control/external-config.json"
  cat >"$external" <<'EOF'
{
  "version": 76,
  "externalMarker": "SNAPSHOT_RACE_DO_NOT_PRINT",
  "providers": [{"id":"codex","enabled":false},{"id":"other","snapshotRace":true}]
}
EOF
  : >"$control/mutate-on-snapshot-chmod"
  output="$case_dir/snapshot-writer.out"
  assert_fails 'external writer during snapshot capture' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  cmp -s "$external" "$config" || fail 'helper overwrote snapshot-capture writer content' || return 1
  assert_contains "$(cat "$output")" 'snapshot capture: live config changed' 'snapshot writer diagnostic' || return 1
  assert_not_contains "$(cat "$output")" 'SNAPSHOT_RACE_DO_NOT_PRINT' 'snapshot writer output privacy' || return 1
  assert_eq 0 "$(backup_count)" 'snapshot-capture race creates no backup' || return 1

  reset_case external-writer
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  external="$control/external-config.json"
  cat >"$external" <<'EOF'
{
  "version": 77,
  "externalMarker": "EXTERNAL_DO_NOT_PRINT_PRIVATE_VALUE",
  "providers": [{"id":"codex","enabled":false},{"id":"other","external":true}]
}
EOF
  printf '2\n' >"$control/mutate-on-call"
  output="$case_dir/external-writer.out"
  assert_fails 'external writer before commit' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  cmp -s "$external" "$config" || fail 'helper overwrote external writer content' || return 1
  assert_contains "$(cat "$output")" 'immediate pre-commit check: live config changed' 'external writer diagnostic' || return 1
  assert_not_contains "$(cat "$output")" 'EXTERNAL_DO_NOT_PRINT_PRIVATE_VALUE' 'external writer output privacy' || return 1
  [[ "$(backup_count)" -eq 1 ]] || fail 'external writer race retains exactly one original backup' || return 1
  cmp -s "$before" "$(find "$backup_dir" -type f -name '*.bak*' -print -quit)" \
    || fail 'external writer race backup is the verified original snapshot' || return 1

  reset_case app-start
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  printf '2\n' >"$control/app-start-on-call"
  output="$case_dir/app-start.out"
  assert_fails 'app starts before commit' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  cmp -s "$before" "$config" || fail 'app-start race modified config' || return 1
  assert_contains "$(cat "$output")" 'started during reconciliation' 'app-start diagnostic' || return 1
}

scenario_exact_mode_requirement() {
  local before output

  reset_case mode-noop
  write_managed_config
  chmod 644 "$config"
  before="$case_dir/before.json"
  cp "$config" "$before"
  output="$case_dir/check.out"
  assert_fails 'non-0600 no-op check' run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
  assert_contains "$(cat "$output")" 'mode must be exactly 0600' 'no-op mode diagnostic' || return 1
  cmp -s "$before" "$config" || fail 'mode failure changed no-op config bytes' || return 1

  reset_case mode-mutation
  write_base_config
  chmod 640 "$config"
  before="$case_dir/before.json"
  cp "$config" "$before"
  output="$case_dir/reconcile.out"
  assert_fails 'non-0600 mutation' run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_contains "$(cat "$output")" 'mode must be exactly 0600' 'mutation mode diagnostic' || return 1
  cmp -s "$before" "$config" || fail 'mode failure changed mutation config bytes' || return 1
  assert_eq 0 "$(backup_count)" 'mode failures create no backup'
}

scenario_signal_rollback() {
  local signal expected_status status before backup output
  for signal in HUP INT TERM; do
    case "$signal" in
      HUP) expected_status=129 ;;
      INT) expected_status=130 ;;
      TERM) expected_status=143 ;;
    esac
    reset_case "signal-${signal}"
    write_base_config
    before="$case_dir/before.json"
    cp "$config" "$before"
    : >"$control/signal-window"
    output="$case_dir/signal.out"

    # Python launches the helper as a normal child rather than an asynchronous
    # shell job, whose inherited SIGINT disposition may be ignored by design.
    status="$(python3 "$race_driver" signal-rollback \
      --helper "$helper" \
      --config "$config" \
      --profile-home "$profile_home" \
      --backup-dir "$backup_dir" \
      --state-dir "$state_home" \
      --control-dir "$control" \
      --output "$output" \
      --path "$PATH" \
      --xdg-state-home "$state_home/ambient" \
      --signal-name "$signal")" || return 1
    assert_eq "$expected_status" "$status" "$signal exit status" || return 1
    cmp -s "$before" "$config" || fail "$signal did not restore original bytes" || return 1
    assert_mode_600 "$config" || return 1
    backup="$(find "$backup_dir" -type f -name '*.bak*' -print -quit)"
    [[ -f "$backup" ]] || fail "$signal backup missing" || return 1
    cmp -s "$before" "$backup" || fail "$signal backup differs from original" || return 1
    [[ ! -e "$state_home/codexbar-config/lock" ]] || fail "$signal left a lock" || return 1
    assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' "$signal output privacy" || return 1
  done
}

scenario_lock_initialization_recovery() {
  local injection output lock first_pid attempts
  for injection in fail-lock-chmod fail-pid-chmod read-only-lock; do
    reset_case "lock-${injection}"
    write_managed_config
    : >"$control/$injection"
    output="$case_dir/injected.out"
    assert_fails "$injection" run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
    lock="$state_home/codexbar-config/lock"
    [[ ! -e "$lock" ]] || fail "$injection left an owned partial lock" || return 1
    rm "$control/$injection"
    run_helper "$case_dir/retry.out" check --config "$config" --profile-home "$profile_home" || return 1
  done

  reset_case unowned-pidless-lock
  write_managed_config
  lock="$state_home/codexbar-config/lock"
  mkdir -p "$lock"
  touch -t 200001010000 "$lock"
  output="$case_dir/unowned.out"
  assert_fails 'unowned PID-less lock' run_helper "$output" check --config "$config" --profile-home "$profile_home" || return 1
  [[ -d "$lock" ]] || fail 'unowned PID-less lock was removed' || return 1
  assert_contains "$(cat "$output")" 'ownership cannot be proven' 'PID-less lock diagnostic' || return 1
  rm -rf "$state_home"

  reset_case paused-live-initializer
  write_managed_config
  : >"$control/pause-lock-init"
  TEST_XDG_STATE_HOME="$case_dir/ambient-a" \
    run_helper "$case_dir/first.out" check --config "$config" --profile-home "$profile_home" &
  first_pid=$!
  attempts=0
  while [[ ! -f "$control/lock-init-paused" && $attempts -lt 500 ]]; do
    sleep 0.02
    attempts=$((attempts + 1))
  done
  [[ -f "$control/lock-init-paused" ]] || { kill "$first_pid" 2>/dev/null || true; fail 'initializer did not pause'; return 1; }
  lock="$state_home/codexbar-config/lock"
  [[ -d "$lock" && ! -e "$lock/pid" ]] || fail 'paused initializer is not PID-less' || return 1
  if TEST_XDG_STATE_HOME="$case_dir/ambient-b" \
    run_helper "$case_dir/second.out" check --config "$config" --profile-home "$profile_home"; then
    fail 'second helper with different ambient XDG state acquired the PID-less lock' || return 1
  fi
  [[ -d "$lock" ]] || fail 'second helper removed live initializer lock' || return 1
  [[ ! -e "$case_dir/ambient-a/codexbar-config" && ! -e "$case_dir/ambient-b/codexbar-config" ]] \
    || fail 'ambient XDG_STATE_HOME selected a caller-controlled lock namespace' || return 1
  : >"$control/lock-init-release"
  wait "$first_pid" || return 1
  [[ ! -e "$lock" ]] || fail 'owning initializer did not clean its lock'
}

scenario_noop_snapshot_validation_races() {
  local op output external status target
  for op in check reconcile remove-managed-profile; do
    reset_case "noop-race-${op}"
    if [[ "$op" == remove-managed-profile ]]; then
      write_base_config
    else
      write_managed_config
    fi
    external="$control/external-config.json"
    cat >"$external" <<'EOF'
{
  "version": 88,
  "externalMarker": "NOOP_RACE_DO_NOT_PRINT",
  "providers": [{"id":"codex","enabled":false},{"id":"other","noopRace":true}]
}
EOF
    : >"$control/noop-validation-window"
    output="$case_dir/noop-race.out"
    status="$(python3 "$race_driver" noop-snapshot-race \
      --helper "$helper" \
      --config "$config" \
      --profile-home "$profile_home" \
      --backup-dir "$backup_dir" \
      --state-dir "$state_home" \
      --control-dir "$control" \
      --output "$output" \
      --path "$PATH" \
      --xdg-state-home "$state_home/ambient" \
      --operation "$op" \
      --external-config "$external")" || return 1
    [[ "$status" != 0 ]] || fail "$op emitted a stale no-op success" || return 1
    cmp -s "$external" "$config" || fail "$op overwrote concurrent no-op writer content" || return 1
    assert_not_contains "$(cat "$output")" 'status=' "$op stale status suppression" || return 1
    assert_not_contains "$(cat "$output")" 'NOOP_RACE_DO_NOT_PRINT' "$op no-op race privacy" || return 1
    assert_contains "$(cat "$output")" 'live config changed' "$op no-op race diagnostic" || return 1
    target="$(tail -n 1 "$control/validate-targets.log")"
    [[ "$target" == "$case_dir"/.config.json.codexbar-snapshot.* ]] \
      || fail "$op CLI validation did not target the immutable snapshot" || return 1
  done
}

scenario_post_commit_reporting_is_best_effort() {
  local output
  reset_case reporting-error
  write_base_config
  printf '4\n' >"$control/probe-error-on-call"
  output="$case_dir/reconcile.out"
  run_helper "$output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  assert_contains "$(cat "$output")" 'operation=reconcile status=changed' 'committed success survives report probe error' || return 1
  assert_contains "$(cat "$output")" 'running=unknown' 'report probe error is summarized as unknown' || return 1
  jq -e --arg managed "$profile_home" \
    '.providers[] | select(.id == "codex") | .codexProfileHomePaths == [$managed]' \
    "$config" >/dev/null || fail 'committed config missing after report probe error'
}

scenario_post_commit_validation_races() {
  local before external output status

  reset_case post-commit-rewrite
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  external="$control/external-config.json"
  cat >"$external" <<'EOF'
{
  "version": 91,
  "externalMarker": "POST_COMMIT_RACE_DO_NOT_PRINT",
  "providers": [{"id":"codex","enabled":false},{"id":"other","postCommitRace":true}]
}
EOF
  : >"$control/signal-window"
  output="$case_dir/post-commit-rewrite.out"
  status="$(python3 "$race_driver" post-commit-rewrite \
    --helper "$helper" \
    --config "$config" \
    --profile-home "$profile_home" \
    --backup-dir "$backup_dir" \
    --state-dir "$state_home" \
    --control-dir "$control" \
    --output "$output" \
    --path "$PATH" \
    --xdg-state-home "$state_home/ambient" \
    --external-config "$external")" || return 1
  [[ "$status" != 0 ]] || fail 'post-commit rewrite emitted stale success' || return 1
  cmp -s "$external" "$config" || fail 'post-commit rewrite was overwritten by rollback' || return 1
  assert_contains "$(cat "$output")" 'live config changed during CLI validation' 'post-commit rewrite diagnostic' || return 1
  assert_not_contains "$(cat "$output")" 'status=' 'post-commit rewrite status suppression' || return 1
  assert_not_contains "$(cat "$output")" 'POST_COMMIT_RACE_DO_NOT_PRINT' 'post-commit rewrite output privacy' || return 1
  cmp -s "$before" "$(find "$backup_dir" -type f -name '*.bak*' -print -quit)" \
    || fail 'post-commit rewrite backup is not the original snapshot' || return 1

  reset_case post-commit-app-start
  write_base_config
  : >"$control/signal-window"
  output="$case_dir/post-commit-app-start.out"
  status="$(python3 "$race_driver" post-commit-app-start \
    --helper "$helper" \
    --config "$config" \
    --profile-home "$profile_home" \
    --backup-dir "$backup_dir" \
    --state-dir "$state_home" \
    --control-dir "$control" \
    --output "$output" \
    --path "$PATH" \
    --xdg-state-home "$state_home/ambient")" || return 1
  [[ "$status" != 0 ]] || fail 'post-commit app start emitted stale success' || return 1
  jq -e --arg managed "$profile_home" \
    '.providers[] | select(.id == "codex") | .codexProfileHomePaths == [$managed]' \
    "$config" >/dev/null || fail 'validated replacement disappeared after app-start detection' || return 1
  assert_contains "$(cat "$output")" 'CodexBar started during CLI validation' 'post-commit app-start diagnostic' || return 1
  assert_not_contains "$(cat "$output")" 'status=' 'post-commit app-start status suppression'
}

scenario_backup_collision_resistance() {
  local before first_state first_output second_output first_backup second_backup
  reset_case backup-collision
  write_base_config
  : >"$control/fixed-date"
  before="$case_dir/before.json"
  cp "$config" "$before"
  first_output="$case_dir/first.out"
  run_helper "$first_output" reconcile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  first_backup="$(backup_from_output "$first_output")"
  first_state="$case_dir/first-state.json"
  cp "$config" "$first_state"

  second_output="$case_dir/second.out"
  run_helper "$second_output" remove-managed-profile --config "$config" --profile-home "$profile_home" --backup-dir "$backup_dir" || return 1
  second_backup="$(backup_from_output "$second_output")"
  [[ "$first_backup" != "$second_backup" ]] || fail 'exclusive backup allocation reused a retained path' || return 1
  [[ -f "$first_backup" && -f "$second_backup" ]] || fail 'collision fixture backups are missing' || return 1
  cmp -s "$before" "$first_backup" || fail 'first collision fixture backup was overwritten' || return 1
  cmp -s "$first_state" "$second_backup" || fail 'second collision fixture backup is not its source snapshot' || return 1
  assert_eq 2 "$(backup_count)" 'same-timestamp writes retain two exclusive backups' || return 1
  assert_contains "$first_backup" '20260101T000000Z.bak.' 'first backup uses exclusive timestamp prefix' || return 1
  assert_contains "$second_backup" '20260101T000000Z.bak.' 'second backup uses exclusive timestamp prefix'
}

scenario_corrupted_backup_restores_verified_snapshot() {
  local before output status backup
  reset_case corrupted-backup-rollback
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  : >"$control/signal-window"
  : >"$control/reject-all"
  output="$case_dir/corrupted-backup.out"

  status="$(python3 "$race_driver" corrupted-backup-restore \
    --helper "$helper" \
    --config "$config" \
    --profile-home "$profile_home" \
    --backup-dir "$backup_dir" \
    --state-dir "$state_home" \
    --control-dir "$control" \
    --output "$output" \
    --path "$PATH" \
    --xdg-state-home "$state_home/unrelated-ambient")" || return 1

  [[ "$status" != 0 ]] || fail 'CLI rejection with corrupted backup unexpectedly succeeded' || return 1
  cmp -s "$before" "$config" || fail 'verified snapshot did not restore original bytes' || return 1
  assert_mode_600 "$config" || return 1
  backup="$(find "$backup_dir" -type f -name '*.bak*' -print -quit)"
  [[ -f "$backup" ]] || fail 'corrupted retained backup is missing' || return 1
  assert_contains "$(cat "$backup")" 'CORRUPTED_RETAINED_BACKUP' 'retained backup was consumed or replaced' || return 1
  assert_contains "$(cat "$output")" 'original restored' 'verified-snapshot restore diagnostic' || return 1
  assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'corrupted-backup rollback output privacy' || return 1
  [[ ! -e "$state_home/codexbar-config/lock" ]] || fail 'corrupted-backup rollback left a lock'
}

scenario_interrupted_restore_is_nonreentrant() {
  local before output status backup
  reset_case restore-interruption
  write_base_config
  before="$case_dir/before.json"
  cp "$config" "$before"
  : >"$control/signal-window"
  : >"$control/pause-restore-chmod"
  output="$case_dir/restore-interruption.out"
  status="$(python3 "$race_driver" interrupted-restore \
    --helper "$helper" \
    --config "$config" \
    --profile-home "$profile_home" \
    --backup-dir "$backup_dir" \
    --state-dir "$state_home" \
    --control-dir "$control" \
    --output "$output" \
    --path "$PATH" \
    --xdg-state-home "$state_home/ambient")" || return 1
  assert_eq 129 "$status" 'deferred signal after interrupted restore' || return 1
  cmp -s "$before" "$config" || fail 'interrupted restore did not preserve original bytes' || return 1
  assert_mode_600 "$config" || return 1
  backup="$(find "$backup_dir" -type f -name '*.bak*' -print -quit)"
  [[ -f "$backup" ]] || fail 'interrupted restore backup missing' || return 1
  [[ -z "$(find "$case_dir" -type f -name '.*codexbar-restore.*' -print -quit)" ]] \
    || fail 'interrupted restore temp file escaped global cleanup' || return 1
  [[ ! -e "$state_home/codexbar-config/lock" ]] || fail 'interrupted restore left a lock' || return 1
  assert_not_contains "$(cat "$output")" 'DO_NOT_PRINT_PRIVATE_VALUE' 'interrupted restore output privacy'
}

scenario_process_probe_contract() {
  local expected line
  reset_case process-probe
  write_managed_config
  run_helper "$case_dir/check.out" check --config "$config" --profile-home "$profile_home" || return 1
  [[ ! -e "$control/pgrep-invalid.log" ]] || fail 'process probe used unexpected arguments' || return 1
  expected=$'3\t-f\t-x\t/Applications/CodexBar[.]app/Contents/MacOS/CodexBar'
  [[ -s "$control/pgrep.log" ]] || fail 'process probe was not invoked' || return 1
  while IFS= read -r line; do
    assert_eq "$expected" "$line" 'exact escaped process probe argv' || return 1
  done <"$control/pgrep.log"
}

scenario_syntax() {
  local fake_name fake_path
  bash -n "$helper" || return 1
  bash -n "$repo_root/tests/codexbar-config-test.sh" || return 1
  for fake_name in "${generated_bash_fake_names[@]}"; do
    fake_path="$fake_bin/$fake_name"
    [[ -f "$fake_path" ]] || fail "generated Bash fake is missing: $fake_name" || return 1
    bash -n "$fake_path" || return 1
  done
  python3 -m py_compile "$race_driver" || return 1
}

setup_fake_commands || exit 1
write_race_driver || exit 1
run_scenario 'normal reconcile, check, idempotence, numeric fidelity, and privacy' scenario_reconcile_check_idempotence
run_scenario 'exact duplicate collapse and targeted removal' scenario_duplicate_and_removal
run_scenario 'malformed and unexpected shapes fail closed' scenario_malformed_shapes
run_scenario 'precedence shadow probes fail closed' scenario_precedence_shadowing
run_scenario 'running-app abort, deferral, and no-op behavior' scenario_running_and_deferral
run_scenario 'live/stale/parallel locks and permission boundaries' scenario_locking_and_permissions
run_scenario 'immutable snapshot and immediate pre-commit race exclusion' scenario_concurrent_change_exclusion
run_scenario 'exact 0600 mode requirement for no-op and mutation' scenario_exact_mode_requirement
run_scenario 'HUP, INT, and TERM restore after replacement' scenario_signal_rollback
run_scenario 'partial lock initialization cleanup and fail-closed contention' scenario_lock_initialization_recovery
run_scenario 'snapshot-bound no-op validation race exclusion' scenario_noop_snapshot_validation_races
run_scenario 'post-commit validation race exclusion' scenario_post_commit_validation_races
run_scenario 'post-commit reporting is best-effort' scenario_post_commit_reporting_is_best_effort
run_scenario 'exclusive backup collision resistance' scenario_backup_collision_resistance
run_scenario 'corrupted retained backup restores from verified immutable snapshot' scenario_corrupted_backup_restores_verified_snapshot
run_scenario 'interrupted restoration is deferred and non-reentrant' scenario_interrupted_restore_is_nonreentrant
run_scenario 'exact literal process-probe arguments' scenario_process_probe_contract
run_scenario 'CLI unknown-key behavior and validation rollback' scenario_cli_unknown_and_rollback
run_scenario 'path validation and missing-target guidance' scenario_invalid_inputs_and_missing_target
run_scenario 'Bash syntax' scenario_syntax

printf '\nSummary: %d PASS, %d FAIL\n' "$passes" "$failures"
((failures == 0))
