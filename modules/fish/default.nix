{ config, pkgs, ... }:

let
  mkOOS = config.lib.file.mkOutOfStoreSymlink;
  fishModuleDir = "${config.home.homeDirectory}/Projects/personal/dotfiles/modules/fish";
in
{
  # Fish functions and completions are linked from this repo into
  # ~/.config/fish/{functions,completions}/ via Home Manager.
  #
  # functions/ uses out-of-store mapping per ADR-019 condition 3
  # (authored shell helpers iterated multiple times per week — rebuild
  # loop is friction tax). Supersedes ADR-009 for functions.
  #
  # functions/  → single-dir mkOutOfStoreSymlink (no `recursive`).
  #   The whole directory is one live symlink. Add, edit, rename, or
  #   delete *.fish files in modules/fish/functions/ and
  #   they are visible to fish immediately, no rebuild required.
  #   Already-loaded functions in a running shell still need re-source:
  #     functions --erase <name>
  #
  # completions/ stays store-managed (recursive = true) because:
  #   1. The generated mise.fish below needs to layer into the same
  #      destination dir, and HM's mkOutOfStoreSymlink does not compose
  #      with layered explicit entries ("Error installing file outside
  #      $HOME").
  #   2. Authored completions are operational (nix-ops, bvp, etc.) and
  #      not iterated frequently — they don't meet ADR-019 condition 3.
  #
  # IMPORTANT: keep the source directories clean — only intended *.fish
  # files. No .DS_Store, editor swapfiles, or stray temp files.
  xdg.configFile = {
    # Fish functions (live, including the a_mp/ subdirectory which fish
    # loads via fish_function_path in shellInit). `force = true` clears
    # the pre-existing ~/.config/fish/functions/ directory containing
    # per-file HM symlinks left over from the previous store-managed +
    # recursive=true setup so the first activation can replace it with
    # the single dir symlink.
    #
    # WARNING: `force = true` removes the *entire* target directory at
    # activation, not only HM-tracked entries. Verified before adopting
    # this pattern that ~/.config/fish/functions/ contained nothing but
    # HM-managed symlinks. Do NOT save local `funcsave` files there or
    # drop manual scripts in — they would be wiped on the next switch.
    # Author functions in this repo dir instead.
    "fish/functions" = {
      source = mkOOS "${fishModuleDir}/functions";
      force = true;
    };

    # Fish completions (store-managed; per-file via recursive so the
    # generated mise entry below can layer alongside).
    "fish/completions" = {
      source = ./completions;
      recursive = true;
    };

    # Generated from binaries at build time (always in sync with the
    # installed version). Kept explicit because it is produced by
    # `runCommand` and tied to the installed package version, not
    # authored source files. pnpm is not generated here because Corepack,
    # not Nix, owns the active repo-specific pnpm version.
    "fish/completions/mise.fish".source = pkgs.runCommand "mise-fish-completions" { } ''
      ${pkgs.mise}/bin/mise completion fish > $out
    '';
  };

  programs.fish = {
    enable = true;

    shellAbbrs = {
      # Core
      v = "nvim";
      lv = "NVIM_APPNAME=nvim-lua nvim";
      c = "clear";
      r = "reset";
      q = "exit";
      n = "fastfetch";
      R = "ranger";
      f = "fzf --preview='bat --color=always --style=numbers --line-range=:500 {}'";

      # Claude/Codex CLI - DO NOT TOUCH PERMISSIONS HERE AS USER EXPLICITLY REQUESTED THIS
      # YOU MUST NOT REMOVE THE FULL ACCESS/NO APPROVAL HERE!
      # IF YOU CHANGE THIS, I WILL HUNT AND SHUT YOU DOWN!
      cdx = "codex-launch --sandbox=danger-full-access --ask-for-approval=never";
      gpth = "codex -m gpt-5.2 -c model_reasoning_effort=high --sandbox=danger-full-access --ask-for-approval=never -c sandbox_workspace_write.network_access=true";
      gptxh = "codex -m gpt-5.2 -c model_reasoning_effort=xhigh --sandbox=danger-full-access --ask-for-approval=never -c sandbox_workspace_write.network_access=true";

      # ccy: full-access Claude through claude-launch, which uses CLIProxyAPI unless the
      # Claude route setting is off (claude-proxy-route; see the cli-proxy-api runbook).
      # ccy does not go through clm, so there is no context/repo-prompt-ce and no
      # --strict-mcp-config: Claude loads its ordinary MCP configuration.
      ccy = "claude-launch --dangerously-skip-permissions";

      # ccnt: full-access clm with file built-ins disabled, so editing routes through
      # RepoPrompt CE only. clm prepends context/repo-prompt-ce; extra config args compose additional MCP servers.
      ccnt = "clm --dangerously-skip-permissions --disallowedTools \"Write,Read,Edit,Grep,Glob\"";
      autoplan = "claude --dangerously-skip-permissions --append-system-prompt \"$(cat ~/.claude/prompts/auto-plan-mode.txt)\"";

      # Legacy editors
      spacemacs = "emacs -nw --debug-init";
      spcmacs = "emacs -nw";

      # Package managers
      p = "pnpm";
      pi = "pnpm install --prefer-offline";

      # Phoenix/Elixir
      phxserver = "iex -S mix phx.server";
      phxroutes = "mix phx.routes";

      # Docker
      dup = "docker-compose up";
      dd = "docker-compose down";
      dcb = "docker-compose build";
      docker-rm-dangling-image = "docker images | grep none | awk \"{ print \\$3; }\" | xargs docker rmi -f";
      dr = "docker-compose run";
      drw = "docker-compose run web";
      drs = "docker-compose run --rm --service-ports web";
      dce = "docker-compose exec web";
      lzd = "lazydocker";

      # Git
      lzg = "lazygit";
      gitignore = "git config --global core.excludesfile ~/.gitignore_global";
      g = "git";
      ga = "git add";
      gc = "git commit";
      gco = "git checkout";
      gd = "git diff";
      gp = "git push";
      gpl = "git pull";
      gs = "git status";

      # AeroSpace layout management

      # Modern CLI replacements
      ls = "lsd --hyperlink=auto --color=auto";
      ll = "lsd -l --hyperlink=auto";
      la = "lsd -la --hyperlink=auto";
      lt = "lsd --tree --hyperlink=auto --color=auto";
      tree = "lsd --tree --hyperlink=auto --color=auto";
      # harder to pipe when cat is always bat
      # cat = "bat";
      top = "btm";
      df = "duf";

      # Clipboard
      pbcp = "pbcopy";
      pwdcp = "pwd | pbcopy";

      # Image/media
      img = "identify -verbose";

      # Kitty
      icat = "kitty +kitten icat";
      kssh = "kitty +kitten ssh";
      xssh = "TERM='xterm-256color' ssh";
      # apparently there's a diff command with autocomplete
      # d = "kitty +kitten diff";
      kcp = "kitty +kitten clipboard --get-clipboard";

      # GCP
      gcpauth = "gcloud auth login";
      gcpadc = "gcloud auth application-default login";

      # Infrastructure
      k = "kubectl";
      tf = "terraform";
      terrafrom = "terraform"; # typo fix

      # Cloudflare tunnels
      tunnel-demo = "cloudflared tunnel run demo"; # localhost:42069 -> demo.mplibunao.com

      # Project scripts
      dc = "./dc";
      cli = "pnpm cli";
      run = "./run";

      # Python
      sourcepython = "source ~/Environments/my_env/bin/activate";
      sourcezshrc = "source ~/.zshrc";

      # Database
      psql = "~/pgbinaries/pg9.6.24/bin/psql";
      pg_restore = "~/pgbinaries/pg16/bin/pg_restore";

      # GCR cleanup
      gcr-clean-dry = "docker run --rm -it -v \"\${HOME}/.config/gcloud:/.config/gcloud\" asia-docker.pkg.dev/gcr-cleaner/gcr-cleaner/gcr-cleaner-cli -repo asia-southeast1-docker.pkg.dev/prj-c-readit-shared-infra-de69/container-repo-c-readit/readit-api -dry-run";
      gcr-clean = "docker run --rm -it -v \"\${HOME}/.config/gcloud:/.config/gcloud\" asia-docker.pkg.dev/gcr-cleaner/gcr-cleaner/gcr-cleaner-cli -repo asia-southeast1-docker.pkg.dev/prj-c-readit-shared-infra-de69/container-repo-c-readit/readit-api --keep 5 -tag-filter-any \"^(\\d+).(\\d+).(\\d+)\\$\"";

      # Misc
      killport = "findandkill";
      lsb = "lsb_release -c -s";
    };

    shellInit = ''
      # Disable greeting
      set -g fish_greeting

      # Add a_mp/ subdirectory to fish_function_path for namespaced functions
      # Fish doesn't recurse into subdirectories, so we add it explicitly
      set -p fish_function_path $__fish_config_dir/functions/a_mp
    '';

    interactiveShellInit = ''
      # Use Fish's keybinding hook pattern for vim mode
      # Chain any existing fish_user_key_bindings (e.g., from fzf.fish) instead of replacing
      set -g fish_key_bindings fish_vi_key_bindings

      # Capture plugin-provided fish_user_key_bindings only once (idempotent on reload)
      # Use type -q to also catch autoloadable functions, force load before copying
      if not functions -q __fish_user_key_bindings_plugin
        if type -q fish_user_key_bindings
          functions fish_user_key_bindings >/dev/null 2>&1
          functions -c fish_user_key_bindings __fish_user_key_bindings_plugin
        end
      end

      function fish_user_key_bindings
        # Run plugin bindings first (if any)
        functions -q __fish_user_key_bindings_plugin; and __fish_user_key_bindings_plugin

        # Ctrl+E to edit command in $EDITOR (all vim modes)
        bind -M insert \ce edit_command_buffer
        bind -M default \ce edit_command_buffer
        bind -M visual \ce edit_command_buffer
      end

      # Apply vi bindings immediately (triggers fish_user_key_bindings)
      fish_vi_key_bindings

      # Initialize starship prompt (use command -q to check binary, not functions)
      if command -q starship
        command starship init fish | source
        # Guard enable_transience - may not exist in all Starship versions
        functions -q enable_transience; and enable_transience
      end

      # Initialize zoxide
      if command -q zoxide
        command zoxide init fish | source
      end

      # Initialize mise (per-repo tool version manager via .tool-versions)
      if command -q mise
        command mise activate fish | source
      end

      # Auto-ls after cd (use lsd directly, not abbreviation which won't expand)
      set -q AUTO_LS; or set -g AUTO_LS true
      function __auto_ls --on-variable PWD --description "Auto ls after cd"
        if test "$AUTO_LS" = "true"
          if status is-interactive
            if command -q lsd
              command lsd --hyperlink=auto --color=auto
            else
              command ls
            end
          end
        end
      end

      # Local overrides (not tracked in git)
      if test -f ~/.config/fish/local.fish
        source ~/.config/fish/local.fish
      end
    '';

    plugins = [
      {
        name = "fzf-fish";
        inherit (pkgs.fishPlugins.fzf-fish) src;
      }
      {
        name = "autopair";
        inherit (pkgs.fishPlugins.autopair) src;
      }
      # Catppuccin Mocha theme for Fish syntax highlighting
      {
        name = "catppuccin";
        src = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "fish";
          rev = "cc8e4d8fffbdaab07b3979131030b234596f18da";
          hash = "sha256-KD/sWXSXYVlV+n7ft4vKFYpIMBB3PSn6a6jz+ZIMZvQ=";
        };
      }
    ];
  };

  # Set fish as default shell via nix-darwin
  # (handled in configuration.nix)
}
