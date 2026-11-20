{ config, ... }:

let
  mkOOS = config.lib.file.mkOutOfStoreSymlink;
  dotfilesDir = "${config.home.homeDirectory}/Projects/personal/dotfiles";
in
{
  # Karabiner-Elements configuration - DIRECTORY SYMLINK
  #
  # Links ~/.config/karabiner directory to the dotfiles-managed version.
  #
  # WHY directory symlink (not just karabiner.json):
  # - karabiner.json references assets under ~/.config/karabiner/ (e.g. rimshot.mp3)
  # - Single file symlink would leave those assets missing
  #
  # OPERATIONAL IMPLICATIONS:
  # - force=true will CLOBBER any existing ~/.config/karabiner directory
  # - Backup your existing config before first darwin-rebuild switch!
  # - Karabiner writes runtime-generated files here (automatic_backups/, assets/)
  # - These are gitignored but may cause working-tree noise in dotfiles
  #
  # ALTERNATIVE: If you want isolated file symlinks instead:
  #   home.file.".config/karabiner/karabiner.json".source = mkOOS "...";
  #   home.file.".config/karabiner/rimshot.mp3".source = mkOOS "...";
  #   # But you'll need to manually create the directory structure
  home.file.".config/karabiner" = {
    source = mkOOS "${dotfilesDir}/modules/karabiner/config";
    force = true;
  };
}
