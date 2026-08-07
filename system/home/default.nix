{ config, ... }:
{
  imports = [
    ./app
    ./wm
    ./bluetooth
    ./lanzaboote.nix
    ./docker.nix
    ./openssh.nix
    ./tailscale.nix
    ./power.nix
    ./iphone.nix
    ./openrazer.nix
    ./swap.nix
  ];
}
