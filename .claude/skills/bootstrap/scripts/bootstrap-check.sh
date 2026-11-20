#!/usr/bin/env bash
#
# bootstrap-check.sh
# ==================
# Idempotent status reporter for Mac bootstrap phases.
# Mostly read-only. Exception: GitHub SSH check may add host key to ~/.ssh/known_hosts.
#
# Usage:
#   bootstrap-check.sh [--json] [--phase]
#
# Return codes:
#   0: phase computed successfully
#   2: missing prerequisites to compute phase

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-check.sh [options]

Options:
  --json      Output JSON with phase and checks
  --phase     Print only the phase number (0-7)
  -h, --help  Show help

Phases:
  0: No Xcode CLT
  1: No SSH key or GitHub access
  2: No dotfiles clone
  3: No Homebrew
  4: No Nix
  5: Nix exists but no build, or built but never switched
  6: Build works, post-bootstrap tooling missing
  7: Complete - ready for handover
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

# Escape string for JSON output
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\b'/\\b}"
  s="${s//$'\f'/\\f}"
  printf '%s' "$s"
}

output_json="false"
output_phase_only="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      output_json="true"
      shift
      ;;
    --phase)
      output_phase_only="true"
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

# A fresh Mac has no Home Manager configuration yet, so the probe uses the
# conventional clone location rather than DOTFILES_DIR or the current directory.
dotfiles_dir="$HOME/Projects/personal/dotfiles"

# Check functions
check_xcode_clt() {
  xcode-select -p >/dev/null 2>&1
}

check_git() {
  have git
}

check_ssh_key() {
  [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$HOME/.ssh/id_rsa" ]]
}

check_github_access() {
  # Use ConnectTimeout and BatchMode to prevent hanging in non-interactive contexts
  # SSH outputs to stderr, so redirect stderr to stdout for grep
  # Use subshell to avoid pipefail issues with ssh's non-zero exit code
  local output
  output="$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)"
  echo "$output" | grep -q "successfully authenticated"
}

check_dotfiles() {
  [[ -f "$dotfiles_dir/flake.nix" ]]
}

check_claude_toolkit() {
  [[ -d "$HOME/Projects/personal/ai/claude-toolkit" ]]
}

check_homebrew() {
  have brew
}

check_nix() {
  have nix
}

check_darwin_rebuild() {
  have darwin-rebuild
}

check_flake_build() {
  # darwin-rebuild build leaves result pointing at the system output; a
  # package built from the repository root would leave a different link.
  local result="$dotfiles_dir/result" target
  target="$(readlink "$result")" || return 1
  [[ "$target" == *-darwin-system-* && -x "$result/activate" ]]
}

check_claude_code() {
  have claude
}

check_codex() {
  have codex
}

check_fish() {
  have fish
}

check_mise() {
  have mise
}

check_node() {
  have node
}

check_nvim() {
  have nvim
}

check_nvim_lazy_config() {
  [[ -d "$HOME/.config/nvim-lazy/.git" ]]
}

# Cheap file existence checks for Neovim config validation
check_nvim_init_lua() {
  [[ -f "$HOME/.config/nvim-lazy/init.lua" ]]
}

check_nvim_lazy_lock() {
  [[ -f "$HOME/.config/nvim-lazy/lazy-lock.json" ]]
}

check_nvim_appname_default() {
  if ! have fish; then
    return 1
  fi
  local appname
  appname="$(fish -lc 'set -q NVIM_APPNAME; and echo $NVIM_APPNAME' 2>/dev/null || true)"
  [[ "$appname" == "nvim-lazy" ]]
}

# Compute phase
phase=0
next_step=""

if ! check_xcode_clt; then
  phase=0
  next_step="Install Xcode CLT: xcode-select --install"
elif ! check_ssh_key; then
  phase=1
  next_step="Generate SSH key: ssh-keygen -t ed25519 -C 'your-email@example.com'"
elif ! check_github_access; then
  phase=1
  next_step="Add SSH key to GitHub: cat ~/.ssh/id_ed25519.pub | pbcopy"
elif ! check_dotfiles; then
  phase=2
  next_step="Clone dotfiles: git clone git@github.com:mplibunao/dotfiles.git ~/Projects/personal/dotfiles"
elif ! check_claude_toolkit; then
  phase=2
  next_step="Clone claude-toolkit: git clone git@github.com:mplibunao/claude-toolkit.git ~/Projects/personal/ai/claude-toolkit"
elif ! check_homebrew; then
  phase=3
  next_step="Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
elif ! check_nix; then
  phase=4
  next_step="Install Determinate Nix: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
elif ! check_flake_build; then
  phase=5
  next_step="Build flake (put your host's name in place of m5-mbp if you added one): cd ~/Projects/personal/dotfiles && nix run nix-darwin#darwin-rebuild -- build --flake .#m5-mbp"
elif ! check_darwin_rebuild; then
  phase=5
  next_step="First switch: after the user approves, give them the Apply command from Phase 5 of the bootstrap runbook"
elif ! check_claude_code && ! check_codex; then
  phase=6
  next_step="Install Claude Code (or Codex): curl -fsSL https://claude.ai/install.sh | bash"
elif ! check_nvim_lazy_config; then
  phase=6
  next_step="Setup Neovim (LazyVim config): .claude/skills/bootstrap/scripts/bootstrap-neovim.sh"
elif ! check_nvim_init_lua; then
  phase=6
  next_step="Neovim config missing init.lua. Re-run: .claude/skills/bootstrap/scripts/bootstrap-neovim.sh"
elif ! check_nvim_lazy_lock; then
  phase=6
  next_step="Neovim plugins not installed. Run: .claude/skills/bootstrap/scripts/bootstrap-neovim.sh --sync"
else
  phase=7
  next_step="Handover complete. Follow AGENTS.md for ongoing work."
fi

# Output
if [[ "$output_phase_only" == "true" ]]; then
  echo "$phase"
  exit 0
fi

if [[ "$output_json" == "true" ]]; then
  cat <<EOF
{
  "phase": $phase,
  "next_step": "$(json_escape "$next_step")",
  "checks": {
    "xcode_clt": $(check_xcode_clt && echo true || echo false),
    "git": $(check_git && echo true || echo false),
    "ssh_key": $(check_ssh_key && echo true || echo false),
    "github_access": $(check_github_access && echo true || echo false),
    "dotfiles": $(check_dotfiles && echo true || echo false),
    "claude_toolkit": $(check_claude_toolkit && echo true || echo false),
    "homebrew": $(check_homebrew && echo true || echo false),
    "nix": $(check_nix && echo true || echo false),
    "darwin_rebuild": $(check_darwin_rebuild && echo true || echo false),
    "flake_build": $(check_flake_build && echo true || echo false),
    "fish": $(check_fish && echo true || echo false),
    "mise": $(check_mise && echo true || echo false),
    "node": $(check_node && echo true || echo false),
    "nvim": $(check_nvim && echo true || echo false),
    "nvim_lazy_config": $(check_nvim_lazy_config && echo true || echo false),
    "nvim_init_lua": $(check_nvim_init_lua && echo true || echo false),
    "nvim_lazy_lock": $(check_nvim_lazy_lock && echo true || echo false),
    "nvim_appname_default": $(check_nvim_appname_default && echo true || echo false),
    "claude_code": $(check_claude_code && echo true || echo false),
    "codex": $(check_codex && echo true || echo false)
  }
}
EOF
  exit 0
fi

# Human-readable output
echo "Bootstrap Phase: $phase/7"
echo
echo "Checks:"
printf "  %-20s %s\n" "Xcode CLT:" "$(check_xcode_clt && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Git:" "$(check_git && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "SSH key:" "$(check_ssh_key && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "GitHub access:" "$(check_github_access && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Dotfiles clone:" "$(check_dotfiles && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Claude toolkit:" "$(check_claude_toolkit && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Homebrew:" "$(check_homebrew && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Nix:" "$(check_nix && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "darwin-rebuild:" "$(check_darwin_rebuild && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Flake build:" "$(check_flake_build && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Fish shell:" "$(check_fish && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "mise:" "$(check_mise && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "node:" "$(check_node && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Neovim:" "$(check_nvim && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "nvim-lazy config:" "$(check_nvim_lazy_config && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "nvim init.lua:" "$(check_nvim_init_lua && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "nvim lazy-lock:" "$(check_nvim_lazy_lock && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "NVIM_APPNAME:" "$(check_nvim_appname_default && echo 'nvim-lazy' || echo '-')"
printf "  %-20s %s\n" "Claude Code:" "$(check_claude_code && echo '✓' || echo '✗')"
printf "  %-20s %s\n" "Codex:" "$(check_codex && echo '✓' || echo '✗')"
echo
echo "Next step:"
echo "  $next_step"
