{
  config,
  dotfilesCheckoutDir,
  lib,
  ...
}:

let
  cfg = config.mp.cloudflared;
  mkOOS = config.lib.file.mkOutOfStoreSymlink;
in
{
  options.mp.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare named tunnel config (manual run lifecycle)";
  };

  config = lib.mkIf cfg.enable {
    home.file.".cloudflared/config.yml" = {
      source = mkOOS "${dotfilesCheckoutDir}/modules/cloudflared/config.yml";
      force = true;
    };
  };
}
