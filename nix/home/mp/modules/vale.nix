{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Global Vale prose-linting config.
  #
  # Applies in every repo on this machine. Repos with their own .vale.ini get
  # a merged view (Vale layers repo-local over global). Repos that don't ship
  # a .vale.ini still get this baseline with zero contributor footprint.
  #
  # Style-choice rationale: see the doc-garden current-state-hygiene plan under
  # ~/references/ai/surf-cli/docs/exec-plans/. Agents reach this config through
  # the `unslop` skill's Vale step in ~/Projects/personal/ai/claude-toolkit.
  #
  # Style choices:
  #   - Microsoft is the global default: work/product-doc repos (WizyVision,
  #     WizyEMM) often can't ship a repo-local .vale.ini, so the global config
  #     favours them. Personal dev-tooling repos opt out by omitting Microsoft
  #     from repo-local styles and running enforcement through `--no-global` wrappers.
  #   - Joblint and Readability at suggestion: advisory, not blocking.
  #   - vale-ai-tells stable + commits: AI-prose tells at upstream severity.
  #     NOT experimental (warning-level; opt-in per repo if wanted).
  #   - ai-tells.ColonUsage off: it flags bold run-in labels ("**Note:** Text"),
  #     a convention these docs use throughout, and the rule's own notes say to
  #     disable it where that convention is established.
  #   - Unslop: house rules vale-ai-tells lacks (decorative emoji, curly quotes).
  #     Nix writes them under StylesPath as dataFiles; `vale sync` leaves them alone.
  #   - mdx adapter via [formats] mapping (no separate package needed).
  #
  # Upgrade discipline:
  #   1. Check https://github.com/tbhb/vale-ai-tells/releases for new versions.
  #   2. Review release notes — new error-level rules can break repos overnight.
  #   3. Update the ai-tells URLs below (release tag URLs are stable but not
  #      cryptographically verified; a deleted+recreated release could silently
  #      change the asset).
  #   4. Run `vale sync` to re-fetch into ~/.local/share/vale/styles/.
  #
  # Post-switch runtime check:
  #   vale ls-config
  # The output should show StylesPath under ~/.local/share/vale/styles and list the loaded
  # config file. On macOS, Vale reads the XDG global config only when
  # $XDG_CONFIG_HOME is set or when ~/.config/vale/.vale.ini exists; confirm
  # it appears. Smoke-test in a directory that has no repo .vale.ini (e.g. $HOME):
  #   cd ~ && echo "# test" > /tmp/vale-smoke.md && vale /tmp/vale-smoke.md; rm /tmp/vale-smoke.md
  # Should lint without "no config file found" warnings.
  xdg = {
    configFile."vale/.vale.ini".text = ''
      # Absolute (XDG data dir) on purpose: `vale sync` writes packages to
      # ~/.local/share/vale/styles, but a relative `styles` resolves against the
      # config dir at lint time (~/.config/vale/styles, which does not exist -> E201).
      # Keep this absolute so sync and lint always agree; do not revert to relative.
      StylesPath = ${config.xdg.dataHome}/vale/styles

      # No global MinAlertLevel on purpose. Vale's default already surfaces all
      # levels, and a global scalar would override (not merge with) a repo's own
      # MinAlertLevel — e.g. a repo that sets `error` for CI parity would be forced
      # back down to suggestion when this global config is present. Leaving it unset
      # keeps the show-everything baseline while letting repo-local thresholds win.

      # Packages installed by `vale sync`. All on one line — Vale's INI parser
      # does not guarantee backslash line-continuation support.
      # ai-tells URLs are release-tag pinned (v1.37.0); see upgrade discipline above.
      Packages = Microsoft, write-good, alex, Joblint, Readability, https://github.com/tbhb/vale-ai-tells/releases/download/v1.37.0/ai-tells.zip, https://github.com/tbhb/vale-ai-tells/releases/download/v1.37.0/ai-tells-commits.zip
      Vocab = Base, Nix, JVM, Go, TypeScript

      # Glob matches both .md and .mdx. The [formats] mdx=md mapping below only
      # controls parsing/syntax — it does NOT make [*.md] rules apply to .mdx;
      # the glob section is what gates which style set runs (verified with Vale 3.x).
      [*.{md,mdx}]
      BasedOnStyles = Vale, Microsoft, write-good, alex, Joblint, Readability, ai-tells, Unslop
      ai-tells.ColonUsage = NO
      Joblint.* = suggestion
      Readability.* = suggestion
      write-good.E-Prime = NO

      [formats]
      # MDX: parse as Markdown (syntax only; the [*.{md,mdx}] glob above is what
      # applies the Markdown style set to .mdx files).
      mdx = md
      # Commit messages: linted against ai-tells commit rules.
      COMMIT_EDITMSG = md

      [{COMMIT_EDITMSG,.git/COMMIT_EDITMSG}]
      BasedOnStyles = ai-tells, ai-tells-commits
    '';

    dataFile = {
      "vale/styles/Unslop/DecorativeEmoji.yml".text = ''
        extends: existence
        message: "Decorative emoji '%s'. Say it in words or drop it."
        level: warning
        nonword: true
        tokens:
          - '[🌀-🫿☀-➿⬆⬇⬅⭐⭕]'
      '';

      "vale/styles/Unslop/CurlyQuotes.yml".text = ''
        extends: existence
        message: "Curly quote '%s'. Use a straight quote."
        level: warning
        nonword: true
        tokens:
          - '[“”‘’]'
      '';

      "vale/styles/config/vocabularies/Base/accept.txt".text = ''
        mp
        MP
        Mark Paolo Libunao
        nvim
        Neovim
        tmux
        LSP
        CLI
        repos?
        dotfiles
        fish
        RepoPrompt
        MCP
        Codex
        Claude
        READMEs?
        ast-grep
        sg
        just
      '';

      "vale/styles/config/vocabularies/Nix/accept.txt".text = ''
        nixd
        nil
        nixfmt
        statix
        deadnix
        nixpkgs
        mkShell
        flakes?
        devShell
        home-manager
        nix-darwin
      '';

      "vale/styles/config/vocabularies/JVM/accept.txt".text = ''
        ktlint
        ktfmt
        gradle
        kotlinc
        jdtls
        kotlin-language-server
      '';

      "vale/styles/config/vocabularies/Go/accept.txt".text = ''
        gopls
        gofmt
        gofumpt
        goimports
        golangci-lint
        delve
        dlv
        gotestsum
        gomodifytags
        impl
      '';

      "vale/styles/config/vocabularies/TypeScript/accept.txt".text = ''
        tsserver
        vtsls
        biome
        oxlint
        eslint
        pnpm
        vite
        Bun
        tsx
        tsconfig
      '';

    };
  };

  # Provision style packs on a fresh machine: Nix manages the .vale.ini and
  # vocabularies above, but the style packages are fetched at runtime by
  # `vale sync`. Check package directories instead of StylesPath emptiness so
  # Nix-managed vocab files do not suppress sync on a fresh machine. Non-fatal:
  # an offline activation logs a hint instead of aborting the switch.
  home.activation.valeSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    valeStyles="${config.xdg.dataHome}/vale/styles"
    missingPackage=0
    for packageDir in Microsoft write-good alex Joblint Readability ai-tells ai-tells-commits; do
      if [ ! -d "$valeStyles/$packageDir" ]; then
        missingPackage=1
      fi
    done

    if [ "$missingPackage" -eq 1 ]; then
      $DRY_RUN_CMD ${pkgs.vale}/bin/vale --config "${config.xdg.configHome}/vale/.vale.ini" sync \
        || echo "vale sync failed (offline?); run 'vale sync' once the network is back" >&2
    fi
  '';
}
