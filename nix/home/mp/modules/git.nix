{ config, lib, ... }:

{
  programs = {
    git = {
      enable = true;

      # Settings merged into ~/.config/git/config
      settings = {
        user = {
          name = "MP";
          email = "markpaololibunao@gmail.com";
        };
        init.defaultBranch = "main";
        rerere.autoupdate = true;
        push.autoSetupRemote = true;
        pull.rebase = true;
        diff.colorMoved = "default";

        alias = {
          co = "checkout";
          redl = "pull origin develop";
          reb = "rebase develop";
          upld = "push origin HEAD";
          addall = "add --all";
          com = "commit -m";
          br = "branch";
          # Delta remains the default pager; Hunk is opt-in for interactive review passes.
          hdiff = "-c core.pager=\"hunk pager\" diff";
          hshow = "-c core.pager=\"hunk pager\" show";
          st = "status";
        };

        # Delta subsections (must be in git settings for proper INI format)
        "delta \"interactive\"" = {
          keep-plus-minus-markers = false;
        };
        "delta \"decorations\"" = {
          commit-decoration-style = "bold yellow box ul";
          file-style = "bold yellow ul";
          file-decoration-style = "none";
          hunk-header-decoration-style = "cyan box ul";
        };
        "delta \"line-numbers\"" = {
          line-numbers-left-style = "cyan";
          line-numbers-right-style = "cyan";
          line-numbers-minus-style = "124";
          line-numbers-plus-style = "28";
        };
      };

      # Work email for work directories
      includes = [
        {
          condition = "gitdir:~/Projects/wizy/";
          contents.user.email = "mp@wizy.io";
        }
      ];

      ignores = [
        # macOS
        ".DS_Store"
        "Thumbs.db"

        # Editors
        ".vscode"
        "*.swp"
        "*.swo"

        # Dependencies
        "node_modules"

        # Build outputs
        "dist"
        "build"
        ".next"

        # Logs
        "*.log"
        "npm-debug.log*"

        # Environment
        ".env.local"
        ".env*.local"
      ];
    };

    # Override interactive.diffFilter to include --features=interactive
    # (HM delta module sets this without the feature flag)
    git.iniContent.interactive.diffFilter = lib.mkForce "${config.programs.delta.package}/bin/delta --color-only --features=interactive";

    # Delta is now a separate program module
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        features = "decorations side-by-side line-numbers";
        navigate = true;
        syntax-theme = "Catppuccin Mocha";
        plus-style = "syntax \"#003800\"";
        minus-style = "syntax \"#3f0001\"";
      };
    };
  };
}
