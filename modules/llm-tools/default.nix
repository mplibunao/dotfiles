{
  config,
  lib,
  opencode,
  pkgs,
  ...
}:

let
  openCodePackage = pkgs.callPackage ../../packages/opencode { opencodeFlake = opencode; };
  # claude-launch/codex-launch are developed in the claude-toolkit checkout.
  # Out-of-store symlinks (ADR-019: iterated scripts) put them on PATH by name
  # without copying them into the store, so toolkit edits apply immediately.
  toolkitScripts = "${config.home.homeDirectory}/Projects/personal/ai/claude-toolkit/scripts";
in
{
  # LLM CLI tools
  #
  # Install methods:
  #   - opencode: pinned upstream flake (tier1.nix) for RepoPrompt Agent Mode/MCP
  #       ~/.local/bin/opencode is a GUI discovery bridge to the same store binary.
  #       Credentials and provider/model config remain OpenCode-owned mutable state;
  #       RepoPrompt normal launches use a process-ephemeral MCP/permission overlay.
  #       This is not a daemon or standalone service configuration.
  #   - claude-code: curl installer → ~/.local/bin/claude - standalone binary
  #       curl -fsSL https://claude.ai/install.sh | bash
  #   - codex: npm global → ~/.npm-global/bin/codex - requires Node runtime
  #       npm install -g @openai/codex
  #   - phone-harness: uv-managed Python environment; Nix owns uv only (ADR-024).
  #       See docs/architecture/runbooks/phone-harness.md; no MCP entry or activation hook.
  #   - gno: Bun global → $BUN_INSTALL/bin/gno - requires Bun runtime
  #       bun install -g @gmickel/gno
  #   - executor: pinned release package and LaunchAgent in modules/executor,
  #       not npm or `executor install`
  #   - cli-proxy-api: pinned release package and LaunchAgent in
  #       modules/cli-proxy/api.nix. The management key stays in a local 0600
  #       file. The usage dashboard LaunchAgent runs its own clone of main
  #       (modules/cli-proxy/dashboard.nix); see the cli-proxy-api runbook.
  #   - rtk: Homebrew (homebrew.nix) - Rust binary, not in nixpkgs
  #       Token-compression proxy for LLM CLI output. After installing it or
  #       running `brew upgrade rtk`, run the `rtk-resync` fish function. It
  #       runs `rtk init -g` for Claude Code with OpenCode, for Codex, and for
  #       Cursor, links rtk's files in ~/.claude, ~/.codex, ~/.cursor, and
  #       ~/.config/opencode to their copies in
  #       ~/Projects/personal/ai/claude-toolkit/, and prints the toolkit diff
  #       to commit. rtk writes through those links on later runs.
  #       Telemetry hard-disabled via RTK_TELEMETRY_DISABLED=1 (common.nix).
  #
  # Why this split:
  #   - opencode: pinned upstream release keeps the RepoPrompt ACP CLI reproducible
  #   - claude-code: official installer has better auto-update than npm
  #   - codex: npm-only distribution
  #   - gno: npm package installed via Bun; repo-local indexes/models stay outside Nix
  #   - rtk: not in nixpkgs; Homebrew formula maintained upstream
  #
  # Cross-shell support:
  #   - Fish: fully supported (`mise activate fish` in modules/fish).
  #   - Other shells (zsh/bash): Codex may not find `node` unless mise is activated
  #     or a Nix-managed Node fallback is added for that shell.
  #   - claude-code works in any shell (standalone binary).

  programs.fish.shellInit = lib.mkAfter ''
    # Home Manager's sessionPath covers login environments; this keeps ad-hoc
    # Fish shells spawned by agents or GUI tasks able to find Bun-installed CLIs.
    fish_add_path -gaP "$BUN_INSTALL/bin"
  '';

  xdg.configFile."opencode/opencode.jsonc".source = ./opencode.jsonc;

  home = {
    file = {
      ".local/bin/opencode".source = "${openCodePackage}/bin/opencode";
      ".local/bin/claude-launch" = {
        source = config.lib.file.mkOutOfStoreSymlink "${toolkitScripts}/claude-launch";
        force = true;
      };
      ".local/bin/codex-launch" = {
        source = config.lib.file.mkOutOfStoreSymlink "${toolkitScripts}/codex-launch";
        force = true;
      };
      ".cursor/mcp.json".source = ./cursor-mcp.json;
    };

    activation = {
      # Ensure global CLI bin directories exist (smooth first-run experience).
      createGlobalCliBins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.npm-global/bin
        $DRY_RUN_CMD mkdir -p ${config.home.homeDirectory}/.cache/.bun/bin
      '';

      # Seed static npm settings into ~/.npmrc without overwriting auth tokens.
      # NPM_CONFIG_* env vars are invisible to npm started by launchd/GUI contexts
      # (editor LSP extensions, git clients firing Husky hooks, LaunchAgents) — those
      # inherit an empty launchd environment. npm reads ~/.npmrc in every context:
      # interactive shell, launchd services, and GUI apps alike. The file must stay
      # writable so `npm login` can update its auth token, and must not be a Nix-store
      # symlink (read-only) or tracked here (world-readable store). So: file is
      # unmanaged/local; only the static keys are seeded each rebuild.
      #
      # Pattern: strip managed keys → re-append canonical values → atomic move.
      # Every other line (auth tokens, etc.) is preserved unchanged.
      seedNpmrc = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [ -n "$DRY_RUN_CMD" ]; then
          echo "would seed ~/.npmrc (prefix, min-release-age, ignore-scripts)"
        else
          _npmrc="${config.home.homeDirectory}/.npmrc"

          if [ -e "$_npmrc" ] && [ ! -f "$_npmrc" ]; then
            echo "refusing to seed non-file $_npmrc" >&2
            exit 1
          fi

          _tmp="$(mktemp "${config.home.homeDirectory}/.npmrc.seed.XXXXXX")"
          trap 'rm -f "$_tmp"' EXIT

          # Preserve all lines we don't own; treat missing file as empty (seed fresh).
          # grep exit 0 = unmanaged lines survived (auth token present) — OK.
          # grep exit 1 = all lines filtered (no token yet) — OK, temp stays empty.
          # grep exit 2+ = real I/O error — abort to avoid silently losing the token.
          if [ -f "$_npmrc" ]; then
            _grep_exit=0
            grep -Ev '^[[:space:]]*(prefix|min-release-age|ignore-scripts)[[:space:]]*=' \
              "$_npmrc" >> "$_tmp" || _grep_exit=$?
            if [ "$_grep_exit" -gt 1 ]; then
              echo "failed to read $_npmrc; refusing to rewrite it" >&2
              exit "$_grep_exit"
            fi
          fi

          # Append the three canonical values
          printf 'prefix=${config.home.homeDirectory}/.npm-global\nmin-release-age=7\nignore-scripts=true\n' \
            >> "$_tmp"

          # Lock down before mv — auth token must never be world-readable
          chmod 0600 "$_tmp"
          mv "$_tmp" "$_npmrc"
          trap - EXIT
        fi
      '';
    };

    sessionVariables = {
      # Make Bun global installs land in the same cache-backed bin directory
      # exposed through sessionPath and Fish's ad-hoc shell path.
      BUN_INSTALL = "$HOME/.cache/.bun";
    };

    # Add global CLI bins to PATH. npm owns Codex; Bun owns gno.
    sessionPath = [
      "$HOME/.npm-global/bin"
      "$BUN_INSTALL/bin"
    ];
  };
}
