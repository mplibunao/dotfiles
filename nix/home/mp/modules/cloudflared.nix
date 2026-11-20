{ config, lib, ... }:

let
  cfg = config.mp.cloudflared;
  mkOOS = config.lib.file.mkOutOfStoreSymlink;
  dotfilesDir = "${config.home.homeDirectory}/Projects/personal/dotfiles";
in
{
  options.mp.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare named tunnel config (manual run lifecycle)";
  };

  config = lib.mkIf cfg.enable {
    home.file.".cloudflared/config.yml" = {
      source = mkOOS "${dotfilesDir}/nix/home/mp/modules/cloudflared/config.yml";
      force = true;
    };
  };
}
