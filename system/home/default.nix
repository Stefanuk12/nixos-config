{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./lanzaboote.nix
    ./bluetooth.nix
    ./docker.nix
    ./iphone.nix
  ];
}
