{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./bluetooth
    ./lanzaboote.nix
    ./docker.nix
    ./iphone.nix
    ./openrazer.nix
    ./swap.nix
  ];
}
