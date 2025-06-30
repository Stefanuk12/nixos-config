{ pkgs, ... }:

{
  services.spotifyd.enable = true;

  home.packages = with pkgs; [
    spotifyd
  ];
}