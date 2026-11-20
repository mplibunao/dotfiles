{ config, dotfilesCheckoutDir, ... }:

{
  # TinyCast rewrites preferences from its UI, qualifying for ADR-019 condition 2.
  home.file.".config/tinycast/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfilesCheckoutDir}/modules/tinycast/settings.json";
}
