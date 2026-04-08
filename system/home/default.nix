{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./lanzaboote.nix
    ./bluetooth.nix
    ./iphone.nix
  ];
}
