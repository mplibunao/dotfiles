_:

{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # Faster nix integration, caches dev shells
    # Note: Fish/Bash/Zsh integrations auto-enabled when those shells are managed by HM
  };
}
