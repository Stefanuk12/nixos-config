{
  lib,
  config,
  pkgs,
  hostName,
  username,
  ...
}:

{
  imports = [
    ./vars.nix
    ../../system/common/settings.nix
    ../../user/common/settings.nix
    ../../user/${hostName}
  ];

  # Identity and paths Home Manager manages.
  home.username = username;
  home.homeDirectory = "/home/" + username;

  # Home Manager release this config targets; don't change without checking release notes.
  home.stateVersion = lib.mkDefault "23.05";

  home.packages = with pkgs; [
    kitty
    sops
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
