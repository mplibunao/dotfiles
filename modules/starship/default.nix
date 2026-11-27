_:

{
  programs.starship = {
    enable = true;
    # Manual integration in modules/fish for transient prompt support
    enableFishIntegration = false;
    # Read config from TOML file (easier to edit, Starship docs are TOML)
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}
