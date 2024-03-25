{ config, ... }:

{
  imports = [
    ./hyprland.nix 
    ./app/virtualisation
  ];
}
