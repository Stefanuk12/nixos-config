{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./bluetooth
    ./lanzaboote.nix
    ./docker.nix
    ./openssh.nix
    ./iphone.nix
    ./openrazer.nix
    ./swap.nix
  ];
}
