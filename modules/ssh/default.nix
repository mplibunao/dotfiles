_:

{
  programs.ssh = {
    enable = true;

    # Opt out of deprecated default values
    enableDefaultConfig = false;

    matchBlocks = {
      # Default/fallback for any host
      "*" = {
        identityFile = "~/.ssh/id_ed25519";
        extraOptions = {
          AddKeysToAgent = "yes";
          UseKeychain = "yes";
        };
      };

      # GitHub
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };

      # Bitbucket (work). Bitbucket Cloud serves SSH on ssh.bitbucket.org; this
      # alias sends existing git@bitbucket.org: remotes there unchanged.
      "bitbucket.org" = {
        hostname = "ssh.bitbucket.org";
        user = "git";
        identityFile = "~/.ssh/bitbucket_wizy";
      };
    };
  };
}
