#!/usr/bin/env bash
#
# bootstrap-neovim.sh
# ===================
# Post-bootstrap helper to set up your Neovim (LazyVim) config on a fresh Mac.
#
# Safe-ish by default:
# - Clones config repo if missing
# - Optionally sets fish universal NVIM_APPNAME (derived from config-dir basename)
# - Does NOT run darwin-rebuild or modify Nix config
#
# Usage:
#   .claude/skills/bootstrap/scripts/bootstrap-neovim.sh [options]
#
# Options:
#   --config-dir DIR   Where to clone the config (default: ~/.config/nvim-lazy)
#   --repo REPO        Git repo to clone (default: git@github.com:mplibunao/neovim-config.git)
#   --branch BRANCH    Git branch (default: main)
#   --no-default       Don't set fish universal NVIM_APPNAME
#   --sync             Attempt a headless Lazy restore/sync (best-effort)
#   --validate         Validate only: no clone, no fish var write. Exit 0=pass, 1=fail.
#                      Note: nvim --headless may write to ~/.local/share and ~/.local/state

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-neovim.sh [options]

Options:
  --config-dir DIR   Config directory (default: ~/.config/nvim-lazy)
  --repo REPO        Config repo (default: git@github.com:mplibunao/neovim-config.git)
  --branch BRANCH    Repo branch (default: main)
  --no-default       Do not set fish universal NVIM_APPNAME
  --sync             Best-effort: run headless Lazy restore/sync
  --validate         Validate only mode: no clone, no fish var write
                     Exit 0=pass, 1=fail
                     Note: nvim --headless may write to ~/.local/share and ~/.local/state
  -h, --help         Show help
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

# Compute XDG_CONFIG_HOME and NVIM_APPNAME for a given config directory.
# If config_dir is under ~/.config, use NVIM_APPNAME.
# Otherwise, set XDG_CONFIG_HOME to the parent directory.
# Outputs: sets nvim_xdg and nvim_appname variables
compute_nvim_env() {
  local dir="$1"
  local parent basename
  parent="$(dirname "$dir")"
  basename="$(basename "$dir")"

  if [[ "$parent" == "$HOME/.config" ]]; then
    nvim_xdg=""
    nvim_appname="$basename"
  else
    # Non-standard location: set XDG_CONFIG_HOME to parent
    nvim_xdg="$parent"
    nvim_appname="$basename"
  fi
}

# Run nvim with correct environment for config_dir.
# Avoids eval for security - uses env array instead.
# Args: all remaining args passed to nvim
# Returns: exit code from nvim
run_nvim() {
  compute_nvim_env "$config_dir"
  local -a env_args=("NVIM_APPNAME=$nvim_appname")
  if [[ -n "$nvim_xdg" ]]; then
    env_args=("XDG_CONFIG_HOME=$nvim_xdg" "${env_args[@]}")
  fi
  env "${env_args[@]}" nvim "$@"
}

# Print the correct invocation command for this config_dir
# Uses printf %q for safe shell-escaped output
print_nvim_command() {
  compute_nvim_env "$config_dir"
  if [[ -n "$nvim_xdg" ]]; then
    printf 'XDG_CONFIG_HOME=%q NVIM_APPNAME=%q nvim\n' "$nvim_xdg" "$nvim_appname"
  else
    printf 'NVIM_APPNAME=%q nvim\n' "$nvim_appname"
  fi
}

# Validate Neovim setup by checking config loads and plugins are configured.
# Returns: 0 on success, 1 on failure
# Note: This checks plugins are *configured*, not necessarily *installed*.
validate_neovim_setup() {
  local output
  local exit_code=0

  echo "Validating Neovim setup..."

  # Check 1: Config loads without error (catches syntax errors)
  output=$(run_nvim --headless -c 'qa!' 2>&1) || {
    echo "Error: Neovim failed to start or config failed to load:" >&2
    echo "$output" >&2
    return 1
  }

  # Check 2: lazy.nvim loads and has plugins configured
  # Use stats().count (total configured) not stats().loaded (currently loaded)
  # Note: This verifies configuration, not that plugins are downloaded
  # Use temp file to avoid multiline issues with :lua command
  local lua_tmp
  lua_tmp="$(mktemp -t nvim-validate.XXXXXX.lua)"

  cat > "$lua_tmp" <<'LUA'
local ok, lazy = pcall(require, "lazy")
if not ok then
  print("ERROR: lazy.nvim not found")
  vim.cmd("cq!")
end
local stats = lazy.stats()
if stats.count == 0 then
  print("ERROR: No plugins configured (stats.count=0)")
  vim.cmd("cq!")
end
print("OK: " .. stats.count .. " plugins configured")
LUA

  output=$(run_nvim --headless -c "luafile $lua_tmp" -c 'qa!' 2>&1) || exit_code=$?
  rm -f -- "$lua_tmp"

  if [[ $exit_code -ne 0 ]] || echo "$output" | grep -q "^ERROR:"; then
    echo "Validation failed:" >&2
    echo "$output" >&2
    return 1
  fi

  echo "$output"
  return 0
}

config_dir="${NVIM_LAZY_CONFIG_DIR:-$HOME/.config/nvim-lazy}"
repo="${NVIM_LAZY_REPO:-git@github.com:mplibunao/neovim-config.git}"
branch="${NVIM_LAZY_BRANCH:-main}"
set_default="true"
sync_plugins="false"
validate_only="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir)
      [[ $# -ge 2 ]] || { echo "Error: --config-dir requires a value" >&2; exit 2; }
      config_dir="$2"
      shift 2
      ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "Error: --repo requires a value" >&2; exit 2; }
      repo="$2"
      shift 2
      ;;
    --branch)
      [[ $# -ge 2 ]] || { echo "Error: --branch requires a value" >&2; exit 2; }
      branch="$2"
      shift 2
      ;;
    --no-default)
      set_default="false"
      shift
      ;;
    --sync)
      sync_plugins="true"
      shift
      ;;
    --validate)
      validate_only="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Normalize config_dir: expand ~ and remove trailing slash
config_dir="${config_dir/#\~/$HOME}"
config_dir="${config_dir%/}"

# Validate-only mode: strict validation, no modifications
if [[ "$validate_only" == "true" ]]; then
  if [[ ! -d "$config_dir" ]]; then
    echo "Error: Config directory not found: $config_dir" >&2
    echo "Run without --validate to clone the config first." >&2
    exit 1
  fi
  if ! have nvim; then
    echo "Error: nvim not found in PATH" >&2
    exit 1
  fi
  if validate_neovim_setup; then
    echo "Validation passed."
    exit 0
  else
    exit 1
  fi
fi

# Create parent directory of config_dir (supports custom --config-dir)
mkdir -p "$(dirname "$config_dir")"

if [[ -d "$config_dir" ]]; then
  if [[ ! -d "$config_dir/.git" ]]; then
    echo "Error: $config_dir exists but is not a git repo; refusing to overwrite." >&2
    echo "Move it aside and re-run, e.g.: mv \"$config_dir\" \"${config_dir}.bak\"" >&2
    exit 1
  fi
  echo "Neovim config already present: $config_dir"
else
  if ! have git; then
    echo "Error: git not found. Install git first (Xcode CLT provides it)." >&2
    exit 1
  fi
  echo "Cloning Neovim config into: $config_dir"
  # Use -- to prevent repo starting with dash from being parsed as option
  git --no-pager -c color.ui=false clone --depth 1 --branch "$branch" -- "$repo" "$config_dir"
fi

if have git; then
  origin="$(git --no-pager -c color.ui=false -C "$config_dir" remote get-url origin 2>/dev/null || true)"
  if [[ -n "${origin:-}" && "$origin" != "$repo" ]]; then
    echo "Warning: origin remote is '$origin' (expected '$repo')."
  fi
fi

if [[ "$set_default" == "true" ]]; then
  compute_nvim_env "$config_dir"
  # Validate nvim_appname contains only safe characters (defense-in-depth)
  if [[ ! "$nvim_appname" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "Error: derived NVIM_APPNAME '$nvim_appname' contains unsupported characters." >&2
    echo "Use alphanumeric, dots, underscores, or hyphens only." >&2
    exit 2
  fi
  if have fish; then
    if [[ -n "$nvim_xdg" ]]; then
      # Non-standard location: can't just set NVIM_APPNAME, need XDG_CONFIG_HOME too
      echo "Note: Non-standard config location requires both env vars."
      echo "To run: $(print_nvim_command)"
      echo "Consider adding to your shell config."
    else
      # Standard ~/.config location: NVIM_APPNAME is sufficient
      # Always use set -Ux directly (nvim-config expects a suffix, not full appname)
      fish -lc 'set -Ux NVIM_APPNAME -- "$argv[1]"' "$nvim_appname" >/dev/null 2>&1 || true
      echo "Set default NVIM_APPNAME=$nvim_appname (fish universal variable)."
    fi
  else
    echo "Note: fish not found; skipping NVIM_APPNAME default."
    echo "You can still run: $(print_nvim_command)"
  fi
fi

sync_failed=false
if [[ "$sync_plugins" == "true" ]]; then
  if have nvim; then
    echo "Attempting headless plugin install..."

    # Use Lazy! (with bang) for synchronous wait-for-completion
    # Single quotes in -c avoid shell history expansion of !
    # Capture output on failure instead of discarding
    sync_output=$(run_nvim --headless -c 'Lazy! restore' -c 'qa!' 2>&1) || {
      echo "Warning: headless ':Lazy! restore' failed:" >&2
      echo "$sync_output" >&2
      echo "Open Neovim and run ':Lazy restore' or ':Lazy sync' manually." >&2
      sync_failed=true
    }

    # Force-build plugins with native dependencies
    # Lazy restore may skip builds if plugins aren't "dirty" (no git changes)
    # This ensures plugins with build steps (native binaries, etc.) are built
    echo "Force-building plugins with build steps..."
    local build_lua
    build_lua="$(mktemp -t nvim-build.XXXXXX.lua)"
    cat > "$build_lua" <<'LUA'
local lazy = require("lazy")
local plugins_with_build = {}
for _, plugin in pairs(lazy.plugins()) do
  if plugin.build then
    table.insert(plugins_with_build, plugin.name)
  end
end
if #plugins_with_build > 0 then
  print("Building " .. #plugins_with_build .. " plugins: " .. table.concat(plugins_with_build, ", "))
  lazy.build({ plugins = plugins_with_build, wait = true, show = false })
else
  print("No plugins with build steps found")
end
LUA
    build_output=$(run_nvim --headless -c "luafile $build_lua" -c 'qa!' 2>&1) || {
      echo "Warning: force-build step had issues:" >&2
      echo "$build_output" >&2
      # Don't fail here - builds might partially succeed
    }
    rm -f -- "$build_lua"
    echo "$build_output"

    # Validate after sync
    if ! validate_neovim_setup; then
      echo "Warning: Neovim validation failed. Check the errors above." >&2
      sync_failed=true
    fi
  else
    echo "Note: nvim not found; skipping plugin sync."
  fi
fi

if [[ "$sync_failed" == "true" ]]; then
  echo "Done (with warnings). Check errors above."
  echo "Try: $(print_nvim_command)"
  exit 1
fi

echo "Done."
echo "Try: $(print_nvim_command)"
