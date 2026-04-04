{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./hyprland.nix
    ./lanzaboote.nix
    ./bluetooth.nix
    ./iphone.nix
  ];
}
