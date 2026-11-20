_:

{
  programs.starship = {
    enable = true;
    # Manual integration in fish.nix for transient prompt support
    enableFishIntegration = false;
    # Read config from TOML file (easier to edit, Starship docs are TOML)
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}
