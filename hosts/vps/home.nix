{
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

  # Don't change without reading the release notes.
  home.stateVersion = "23.05";

  home.packages = with pkgs; [
    sops
  ];

  programs.home-manager.enable = true;
}
