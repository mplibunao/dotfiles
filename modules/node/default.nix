{
  lib,
  ...
}:

{
  # Node.js via mise (replaces fnm — see ADR-020, which supersedes ADR-004).
  #
  # mise itself is installed in tier2 and activated for interactive shells in
  # modules/fish (`mise activate fish`), which puts the active Node on PATH and
  # auto-switches versions on `cd`. Its shims dir is on PATH for non-interactive
  # shells via common.nix. So this module's job is narrow:
  #   1. Re-enable idiomatic version files (.nvmrc / .node-version) for node —
  #      mise 2025.10+ ships these OFF by default, so without this the repos
  #      that pin Node via .nvmrc would be ignored in favour of the global pin.
  #   2. Preserve the Corepack + pnpm ergonomics that previously hung off fnm.
  #
  # The global Node version is intentionally NOT pinned here: mise downloads
  # Node imperatively (never reproducible via Nix anyway), and pinning it in a
  # Nix-managed config.toml would make that file a read-only symlink and break
  # the `mise use -g node@X` workflow. Set the global default with that command.

  programs.fish.shellInit = lib.mkAfter ''
    # Ensure Corepack's pnpm/yarn shims exist in the active mise Node prefix.
    # mise does not shim Corepack-managed package managers, so we install them
    # into the Node prefix ourselves, using the active Node's own bundled
    # corepack (Node <= 24). Node 25+ unbundled corepack, so fall back to the
    # npm-global one (`npm i -g corepack`) by EXPLICIT path — npm's prefix is
    # ~/.npm-global (set in modules/llm-tools). Not a PATH lookup: mise's shims dir
    # is early on PATH and ships a `corepack` shim that, under Node 25+, would
    # dispatch to the active Node where corepack is absent (see ADR-020). Shims
    # count as healthy only if executable, so a stale/non-exec file still
    # triggers a repair. Skips the node spawn when both are already good.
    # Reused by the interactive pnpm/yarn wrappers below for mid-shell self-heal.
    function __mp_ensure_corepack --description 'Enable Corepack pnpm/yarn for the active mise Node'
      command -q mise; or return 1
      set -l prefix (mise where node 2>/dev/null)
      test -n "$prefix"; or return 1
      set -l corepack "$prefix/bin/corepack"
      test -x "$corepack"; or set corepack "$HOME/.npm-global/bin/corepack"
      test -x "$corepack"; or return 1
      if not test -x "$prefix/bin/pnpm"; or not test -x "$prefix/bin/yarn"
        "$corepack" enable --install-directory "$prefix/bin" >/dev/null 2>&1
      end
    end

    if command -q mise; and command -q node
      __mp_ensure_corepack

      # Non-interactive shells (scripts, IDE tasks, `fish -c`) never run the mise
      # activate hook. mise's shims already give them node/npm per-directory;
      # Corepack's pnpm/yarn do not (mise does not shim those). Expose the active
      # Node prefix for pnpm/yarn, but APPENDED: `-gaP` operates on $PATH and
      # places the prefix AFTER the mise shims, so it never shadows mise's
      # per-directory node/npm resolution. (Plain `fish_add_path` writes
      # fish_user_paths, which fish prepends ahead of the shims — verified — so
      # -gaP is required, not -ga.)
      if not status is-interactive
        set -l __node_prefix (mise where node 2>/dev/null)
        test -n "$__node_prefix"; and fish_add_path -gaP "$__node_prefix/bin"
      end
    end
  '';

  # Keep pnpm Fish completions aligned with the active Corepack pnpm without
  # paying Corepack's cost on every interactive startup: the first pnpm call in
  # a shell refreshes the stamped completion file, later calls reuse it.
  programs.fish.interactiveShellInit = lib.mkAfter ''
    function __mp_refresh_pnpm_completion --description 'Refresh pnpm Fish completions for the active Corepack pnpm'
      if set -q __mp_pnpm_completion_refreshed
        return 0
      end
      set -g __mp_pnpm_completion_refreshed 1

      if not command -q pnpm
        return 0
      end

      set -l pnpm_version (command pnpm --version 2>/dev/null)
      set -l completion_dir "$__fish_user_data_dir/vendor_completions.d"
      set -l completion_file "$completion_dir/pnpm.fish"
      set -l stamp_file "$completion_dir/pnpm.version"

      if test -n "$pnpm_version"
        if not test -f "$completion_file"; or not test -f "$stamp_file"; or test (cat "$stamp_file" 2>/dev/null) != "$pnpm_version"
          mkdir -p "$completion_dir"
          command pnpm completion fish >"$completion_file" 2>/dev/null; and printf "%s\n" "$pnpm_version" >"$stamp_file"
        end
      end
    end

    function pnpm --wraps pnpm --description 'pnpm with Corepack self-heal + lazy completion'
      # After mise switches Node on cd, a freshly-installed version may lack
      # Corepack shims. Self-heal only when pnpm is actually missing — zero cost
      # in the common case. __mp_ensure_corepack is defined in shellInit.
      if not command -q pnpm
        __mp_ensure_corepack
      end
      __mp_refresh_pnpm_completion
      command pnpm $argv
    end

    function yarn --wraps yarn --description 'yarn with Corepack self-heal'
      # Symmetric to the pnpm wrapper: enable Corepack on demand when yarn is
      # missing after a mid-shell Node switch (e.g. the yarn-classic work repos).
      # Zero cost when yarn already resolves.
      if not command -q yarn
        __mp_ensure_corepack
      end
      command yarn $argv
    end
  '';

  home = {
    # Re-enable idiomatic version files (.nvmrc / .node-version) for node so
    # existing repos that pin Node that way keep working under mise. Set via env
    # var rather than config.toml so the global config.toml stays writable for
    # `mise use -g`. mise honours a MISE_<SETTING> env override for every
    # setting, and the list form accepts a single bare value ("node").
    sessionVariables = {
      PNPM_HOME = "$HOME/Library/pnpm";
      MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS = "node";
    };

    # pnpm 11 links global package bins into $PNPM_HOME/bin (not $PNPM_HOME
    # itself) and hard-errors on `pnpm i -g` if that dir is absent from PATH.
    # Reference PNPM_HOME (defined above) rather than re-spelling the path, so
    # the two can't drift. Mirrors the `$BUN_INSTALL/bin` convention in
    # modules/llm-tools (and npm's ~/.npm-global/bin).
    sessionPath = [
      "$PNPM_HOME/bin"
    ];

    file.".yarnrc".text = ''
      ignore-scripts true
    '';
  };

  # User-level package manager hardening for ad-hoc installs (`pnpm dlx`,
  # `npx`, and Yarn Classic installs). The release-age gate catches newly
  # compromised versions; script suppression/approval reduces install-time code
  # execution. Running a package binary is still arbitrary code, so review the
  # package before using dlx/npx for anything unfamiliar.
  xdg.configFile."pnpm/rc".text = ''
    minimum-release-age=10080
    minimum-release-age-strict=true
    minimum-release-age-ignore-missing-time=false
    trust-policy=no-downgrade
    block-exotic-subdeps=true
    strict-dep-builds=true
    dangerously-allow-all-builds=false
  '';
}
