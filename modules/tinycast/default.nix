{ config, ... }:

let
  dotfilesDir = "${config.home.homeDirectory}/Projects/personal/dotfiles";
in
{
  # TinyCast rewrites preferences from its UI, qualifying for ADR-019 condition 2.
  home.file.".config/tinycast/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/nix/home/mp/modules/tinycast/settings.json";
}
