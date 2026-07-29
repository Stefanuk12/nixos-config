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

  home.username = username;
  home.homeDirectory = "/home/" + username;

  # Don't change without reading the release notes. 25.05 because hydenix used to force it.
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    kitty
    sops
  ];

  programs.home-manager.enable = true;
}
