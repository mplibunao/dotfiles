#!/usr/bin/env bash
# Exercises cli-proxy-runtime-config without a network or a logged key.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper="${repo_root}/nix/scripts/cli-proxy-runtime-config"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

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

mkey="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
ckey="cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
secrets="${tmp}/secrets.env"
template="${tmp}/template.yaml"
out="${tmp}/state/runtime-config.yaml"
printf 'CLIPROXY_MANAGEMENT_KEY=%s\nCLIPROXY_CLIENT_KEY=%s\n' "$mkey" "$ckey" >"$secrets"
chmod 0600 "$secrets"
printf '%s\n' 'config-version: 8' 'server:' '  host: "127.0.0.1"' '  port: 8317' >"$template"
template_sum="$(cksum "$template")"

rout="$(
  "$helper" --secrets "$secrets" --template "$template" --out "$out" 2>"${tmp}/ok.err"
)"
[[ -z "$rout" ]] || fail "runtime config wrote to stdout"
[[ ! -s "${tmp}/ok.err" ]] || fail "runtime config wrote to stderr"
[[ "$(file_mode "$out")" == "600" ]] || fail "runtime config mode is not 0600"
[[ "$(file_mode "$(dirname "$out")")" == "700" ]] || fail "runtime config directory is not 0700"
[[ "$(cksum "$template")" == "$template_sum" ]] || fail "template was modified"
if grep -q "$mkey" "$out"; then
  fail "runtime config contains the management key"
fi
if ! grep -q "\"${ckey}\"" "$out"; then
  fail "runtime config is missing the quoted client key"
fi
grep -q '^access:' "$out" || fail "runtime config has no access section"
if [[ "$rout" == *"$ckey"* || "$rout" == *"$mkey"* ]]; then
  fail "stdout contained a key"
fi
if grep -q 'deepseek\|^api-keys:\|openai-compatibility' "$out"; then
  fail "runtime config has a DeepSeek entry without DEEPSEEK_API_KEY"
fi

dkey="fixture-deepseek-runtime-config"
ds_secrets="${tmp}/ds-secrets.env"
ds_out="${tmp}/ds/runtime-config.yaml"
cp "$secrets" "$ds_secrets"
printf 'DEEPSEEK_API_KEY=%s\n' "$dkey" >>"$ds_secrets"
chmod 0600 "$ds_secrets"
ds_stdout="$(
  "$helper" --secrets "$ds_secrets" --template "$template" --out "$ds_out" 2>"${tmp}/ds.err"
)"
[[ -z "$ds_stdout" && ! -s "${tmp}/ds.err" ]] || fail "DeepSeek run printed output"
[[ "$(file_mode "$ds_out")" == "600" ]] || fail "DeepSeek runtime config mode is not 0600"
grep -q "\"${ckey}\"" "$ds_out" || fail "DeepSeek runtime config lost the client key"
grep -q "^access:" "$ds_out" || fail "DeepSeek runtime config lost the access section"
grep -q '^api-keys:' "$ds_out" || fail "DeepSeek runtime config has no api-keys section"
grep -q '^  openai-compatibility:' "$ds_out" || fail "missing openai-compatibility"
grep -q 'base-url: "https://api.deepseek.com/v1"' "$ds_out" || fail "missing DeepSeek base-url"
grep -q "api-key: \"${dkey}\"" "$ds_out" || fail "missing quoted DeepSeek key"
for m in deepseek-v4-pro deepseek-flash; do
  grep -q "name: \"${m}\"" "$ds_out" || fail "missing model name ${m}"
  grep -q "alias: \"${m}\"" "$ds_out" || fail "missing model alias ${m}"
done
grep -q "$mkey" "$ds_out" && fail "DeepSeek runtime config contains the management key"

printf 'DEEPSEEK_API_KEY=\n' >"${tmp}/ds-empty.env"
cat "$secrets" "${tmp}/ds-empty.env" >"${tmp}/ds-empty-secrets.env"
chmod 0600 "${tmp}/ds-empty-secrets.env"
"$helper" --secrets "${tmp}/ds-empty-secrets.env" --template "$template" --out "${tmp}/ds-empty.yaml" >/dev/null
grep -q 'deepseek' "${tmp}/ds-empty.yaml" && fail "empty DEEPSEEK_API_KEY produced an entry"

printf 'DEEPSEEK_API_KEY=%s\n' 'bad"key' >>"$secrets"
if "$helper" --secrets "$secrets" --template "$template" --out "${tmp}/ds-bad.yaml" >/dev/null 2>"${tmp}/ds-bad.err"; then
  fail "accepted a DEEPSEEK_API_KEY with a quote"
fi
grep -q 'DEEPSEEK_API_KEY' "${tmp}/ds-bad.err" || fail "missing DeepSeek format refusal"
grep -q 'bad' "${tmp}/ds-bad.err" && fail "DeepSeek format refusal printed the value"
[[ ! -e "${tmp}/ds-bad.yaml" ]] || fail "bad DeepSeek key still wrote a config"
printf 'CLIPROXY_MANAGEMENT_KEY=%s\nCLIPROXY_CLIENT_KEY=%s\n' "$mkey" "$ckey" >"$secrets"

if "$helper" --secrets "$secrets" --template "$template" --out "$out" >/dev/null 2>"${tmp}/rerun.err"; then
  :
else
  fail "rewriting the runtime config failed"
fi
rerun_err="$(cat "${tmp}/rerun.err")"
[[ "$rerun_err" != *"$ckey"* && "$rerun_err" != *"$mkey"* ]] || fail "rewrite printed a key"

ln -s "$template" "${tmp}/link.yaml"
if "$helper" --secrets "$secrets" --template "$template" --out "${tmp}/link.yaml" >/dev/null 2>"${tmp}/link.err"; then
  fail "runtime config replaced a symlink"
fi
grep -q 'symlink' "${tmp}/link.err" || fail "missing symlink refusal"
[[ "$(cksum "$template")" == "$template_sum" ]] || fail "symlink refusal changed the template"

printf '\naccess:\n  api-keys: []\n' >>"$template"
if "$helper" --secrets "$secrets" --template "$template" --out "${tmp}/blocked.yaml" >/dev/null 2>"${tmp}/access.err"; then
  fail "runtime config appended onto an access section"
fi
grep -q 'access:' "${tmp}/access.err" || fail "missing access refusal"
[[ ! -e "${tmp}/blocked.yaml" ]] || fail "failed append still wrote a config"

mgmt_only="${tmp}/mgmt.env"
printf 'CLIPROXY_MANAGEMENT_KEY=%s\n' "$mkey" >"$mgmt_only"
chmod 0600 "$mgmt_only"
printf '%s\n' 'config-version: 8' >"${tmp}/plain.yaml"
if "$helper" --secrets "$mgmt_only" --template "${tmp}/plain.yaml" --out "${tmp}/no-client.yaml" >/dev/null 2>"${tmp}/missing.err"; then
  fail "runtime config ran without a client key"
fi
grep -q 'missing' "${tmp}/missing.err" || fail "missing client-key refusal"
missing_err="$(cat "${tmp}/missing.err")"
[[ "$missing_err" != *"$mkey"* ]] || fail "missing-key error printed the management key"
[[ ! -e "${tmp}/no-client.yaml" ]] || fail "missing client key still wrote a config"

chmod 0644 "$secrets"
if "$helper" --secrets "$secrets" --template "${tmp}/plain.yaml" --out "${tmp}/loose.yaml" >/dev/null 2>"${tmp}/mode.err"; then
  fail "runtime config accepted a loose secrets file"
fi
grep -q '0600' "${tmp}/mode.err" || fail "missing mode refusal"

printf 'ok\n'
