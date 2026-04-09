{ pkgs, ... }:

{
  services.spotifyd.enable = true;

  home.packages = with pkgs.userPkgs; [
    spotifyd
  ];
}
