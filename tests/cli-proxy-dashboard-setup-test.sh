#!/usr/bin/env bash
# Exercises cli-proxy-dashboard-setup without a network or a real key.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper="${repo_root}/scripts/cli-proxy-dashboard-setup"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'fail: %s\n' "$1" >&2
  exit 1
}

# init-secret writes mode 0600 and does not print the value.
home_a="${tmp}/home-a"
mkdir -p "$home_a"
out="$(HOME="$home_a" "$helper" init-secret)"
secrets="${home_a}/.config/cli-proxy-api/secrets.env"
[[ -f "$secrets" ]] || fail "init-secret did not create the file"
if mode="$(stat -c '%a' "$secrets" 2>/dev/null)"; then
  :
else
  mode="$(stat -f '%Lp' "$secrets")"
fi
[[ "$mode" == "600" ]] || fail "mode is ${mode}"
key="$(sed -n 's/^CLIPROXY_MANAGEMENT_KEY=//p' "$secrets")"
[[ "$key" =~ ^[0-9a-f]{64}$ ]] || fail "key is not 32 bytes of hex"
[[ "$out" != *"$key"* ]] || fail "init-secret printed the key"
[[ "$out" == "wrote ${secrets} (mode 0600). The key was not printed." ]] || fail "unexpected init-secret output"
before="$(cksum "$secrets")"
if HOME="$home_a" "$helper" init-secret >/dev/null 2>"${tmp}/second.err"; then
  fail "init-secret overwrote an existing file"
fi
grep -q 'refusing to overwrite' "${tmp}/second.err" || fail "missing overwrite refusal"
[[ "$(cksum "$secrets")" == "$before" ]] || fail "existing secrets file changed"
[[ "$(cat "${tmp}/second.err")" != *"$key"* ]] || fail "overwrite refusal printed the key"

# init-client-key appends to a management-only file, keeps the other lines,
# does not print the key, and refuses a second run or a loose mode.
home_c="${tmp}/home-c"
mkdir -p "${home_c}/.config/cli-proxy-api"
legacy="${home_c}/.config/cli-proxy-api/secrets.env"
mkey_c="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
printf '# keep\nCLIPROXY_MANAGEMENT_KEY=%s' "$mkey_c" >"$legacy"
chmod 0600 "$legacy"
cout="$(HOME="$home_c" "$helper" init-client-key)"
[[ "$cout" == "updated ${legacy} (mode 0600). The key was not printed." ]] || fail "unexpected init-client-key output"
if mode="$(stat -c '%a' "$legacy" 2>/dev/null)"; then :; else mode="$(stat -f '%Lp' "$legacy")"; fi
[[ "$mode" == "600" ]] || fail "init-client-key mode is ${mode}"
grep -qx '# keep' "$legacy" || fail "init-client-key dropped a comment"
[[ "$(sed -n 's/^CLIPROXY_MANAGEMENT_KEY=//p' "$legacy")" == "$mkey_c" ]] || fail "init-client-key changed the management key"
ckey_c="$(sed -n 's/^CLIPROXY_CLIENT_KEY=//p' "$legacy")"
[[ "$ckey_c" =~ ^[0-9a-f]{64}$ ]] || fail "client key is not 32 bytes of hex"
[[ "$cout" != *"$ckey_c"* && "$cout" != *"$mkey_c"* ]] || fail "init-client-key printed a key"
before_c="$(cksum "$legacy")"
if HOME="$home_c" "$helper" init-client-key >/dev/null 2>"${tmp}/client-twice.err"; then
  fail "init-client-key ran twice"
fi
grep -q 'already present' "${tmp}/client-twice.err" || fail "missing already-present refusal"
[[ "$(cksum "$legacy")" == "$before_c" ]] || fail "second init-client-key changed the file"
[[ "$(cat "${tmp}/client-twice.err")" != *"$ckey_c"* ]] || fail "refusal printed the client key"
home_d="${tmp}/home-d"
mkdir -p "${home_d}/.config/cli-proxy-api"
printf 'CLIPROXY_MANAGEMENT_KEY=%s\n' "$mkey_c" >"${home_d}/.config/cli-proxy-api/secrets.env"
chmod 0644 "${home_d}/.config/cli-proxy-api/secrets.env"
if HOME="$home_d" "$helper" init-client-key >/dev/null 2>"${tmp}/client-mode.err"; then
  fail "init-client-key accepted a loose secrets file"
fi
grep -q 'expected 0600' "${tmp}/client-mode.err" || fail "missing mode refusal"
if HOME="${tmp}/nowhere" "$helper" init-client-key >/dev/null 2>"${tmp}/client-missing.err"; then
  fail "init-client-key created a secrets file"
fi
grep -q 'missing' "${tmp}/client-missing.err" || fail "missing-file refusal"

# setup clones a local fixture, builds, prints the SHA, and does not create a secret.
src="${tmp}/src"
git init -q -b main "$src"
git -C "$src" config user.email test@example.com
git -C "$src" config user.name test
printf '%s\n' '{"scripts":{"build":"true"}}' >"${src}/package.json"
git -C "$src" add package.json
git -C "$src" commit -q -m 'fixture'
expected="$(git -C "$src" rev-parse HEAD)"

node_bin="${tmp}/node-bin"
mkdir -p "$node_bin"
printf '%s\n' '#!/bin/sh' 'exit 0' >"${node_bin}/node"
cat >"${node_bin}/pnpm" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$PNPM_LOG"
exit 0
EOF
chmod 0755 "${node_bin}/node" "${node_bin}/pnpm"
log="${tmp}/pnpm.log"
touch "$log"
# Stands in for launchctl: records every call. `print` succeeds, so the job counts as loaded.
launchctl_log="${tmp}/launchctl.log"
cat >"${node_bin}/launchctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$LAUNCHCTL_LOG"
exit 0
EOF
chmod 0755 "${node_bin}/launchctl"
touch "$launchctl_log"

home_b="${tmp}/home-b"
mkdir -p "$home_b"
dest="${home_b}/Projects/personal/cli-proxy-dashboard"
run_setup() {
  HOME="$home_b" \
    CLI_PROXY_DASHBOARD_NODE_BIN="$node_bin" \
    CLI_PROXY_DASHBOARD_LAUNCHCTL="${node_bin}/launchctl" \
    PNPM_LOG="$log" \
    LAUNCHCTL_LOG="$launchctl_log" \
    "$helper" --repo "$dest" --url "$src"
}
first="$(run_setup)"
[[ "$first" == "cli-proxy-dashboard main ${expected}" ]] \
  || fail "setup did not print the SHA: ${first}"
[[ "$(git -C "$dest" rev-parse HEAD)" == "$expected" ]] || fail "checkout SHA differs"
[[ ! -e "${home_b}/.config/cli-proxy-api/secrets.env" ]] || fail "setup created a secrets file"
grep -qx 'install' "$log" || fail "pnpm install was not run"
grep -qx 'run build' "$log" || fail "pnpm run build was not run"
grep -qx "kickstart -k gui/$(id -u)/com.mp.cli-proxy-dashboard" "$launchctl_log" \
  || fail "setup did not restart the dashboard LaunchAgent"
: >"$log"
second="$(run_setup)"
[[ "$second" == "$first" ]] || fail "second setup was not idempotent"
grep -qx 'install' "$log" || fail "second run skipped pnpm install"

# The live checkout only follows main. A checkout on another branch is refused before building.
git -C "$dest" checkout -q -b agent-branch
: >"$log"
if run_setup >/dev/null 2>"${tmp}/branch.err"; then
  fail "setup deployed a checkout on another branch"
fi
grep -q 'expected main' "${tmp}/branch.err" || fail "missing branch refusal"
[[ ! -s "$log" ]] || fail "setup built a checkout on another branch"
git -C "$dest" checkout -q main

printf 'x\n' >>"${dest}/package.json"
if run_setup >/dev/null 2>"${tmp}/dirty.err"; then
  fail "dirty checkout was updated"
fi
grep -q 'uncommitted changes' "${tmp}/dirty.err" || fail "dirty checkout was not refused"

# Without --repo, setup clones to ~/.local/share/cli-proxy-dashboard/app, the same
# path as the Nix module's repoDir default.
home_e="${tmp}/home-e"
mkdir -p "$home_e"
HOME="$home_e" \
  CLI_PROXY_DASHBOARD_NODE_BIN="$node_bin" \
  CLI_PROXY_DASHBOARD_LAUNCHCTL="${node_bin}/launchctl" \
  PNPM_LOG="$log" \
  LAUNCHCTL_LOG="$launchctl_log" \
  "$helper" --url "$src" >/dev/null
[[ "$(git -C "${home_e}/.local/share/cli-proxy-dashboard/app" rev-parse HEAD)" == "$expected" ]] \
  || fail "default checkout is not ~/.local/share/cli-proxy-dashboard/app"

printf 'ok\n'
