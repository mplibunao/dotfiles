# Reads one CLIPROXY_* key from a mode-0600 file outside the Nix store.
#
# The value is assigned to a shell variable and must not be echoed. Callers
# unset that variable before they return. Do not run the generated snippet
# under `set -x`: bash would trace the assignment.
#
# There is no sops or agenix setup in this repo. Executor and the surf gateway
# do not keep service secrets either. The nearby pattern is llm-tools.nix
# seeding ~/.npmrc as a local 0600 file so tokens never become a store path.
{ lib }:
rec {
  # Public placeholder. A real key must replace it before the service starts.
  placeholder = "replace-with-a-long-random-string";

  # `envName` is the key in the file. `varName` is a shell variable name, not
  # a path. `secretsFile` is absolute.
  readKeyCommand = envName: varName: secretsFile: ''
    if [ ! -f ${lib.escapeShellArg secretsFile} ]; then
      echo "cli-proxy: ${secretsFile} is missing." >&2
      echo "  Create it mode 0600 with ${envName}=${placeholder}." >&2
      echo "  Steps: nix/docs/runbooks/cli-proxy-api.md" >&2
      exit 1
    fi
    _cliproxy_mode=$(/usr/bin/stat -f '%Lp' ${lib.escapeShellArg secretsFile})
    case "$_cliproxy_mode" in
      600) ;;
      *)
        echo "cli-proxy: ${secretsFile} is mode $_cliproxy_mode; run chmod 0600 on it." >&2
        exit 1
        ;;
    esac
    ${varName}=$(
      CLIPROXY_PLACEHOLDER=${lib.escapeShellArg placeholder} /usr/bin/awk '
        function trim(s) {
          sub(/^[[:space:]]+/, "", s)
          sub(/[[:space:]]+$/, "", s)
          return s
        }
        /^[[:space:]]*($|#)/ { next }
        {
          eq = index($0, "=")
          if (eq == 0) next
          k = trim(substr($0, 1, eq - 1))
          sub(/^export[[:space:]]+/, "", k)
          if (k != "${envName}") next
          v = trim(substr($0, eq + 1))
          if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
          if (v == "") {
            err = "empty"
            exit 2
          }
          if (v == ENVIRON["CLIPROXY_PLACEHOLDER"]) {
            err = "placeholder"
            exit 2
          }
          print v
          err = "ok"
          exit 0
        }
        END {
          if (err == "ok") exit 0
          if (err == "empty") {
            print "cli-proxy: ${envName} is empty." > "/dev/stderr"
            exit 2
          }
          if (err == "placeholder") {
            print "cli-proxy: ${envName} is still the placeholder." > "/dev/stderr"
            exit 2
          }
          print "cli-proxy: ${envName} is missing from the secrets file." > "/dev/stderr"
          exit 2
        }
      ' ${lib.escapeShellArg secretsFile}
    ) || exit 1
  '';

  readCommand = readKeyCommand "CLIPROXY_MANAGEMENT_KEY";
}
