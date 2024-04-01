{ config, ... }:

{
  imports = [
    ./hyprland.nix
    ./lanzaboote.nix 
    ./app/virtualisation
  ];
}
