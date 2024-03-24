{ config, ... }:

{
  imports = [
    ./hyprland
    ./waybar.nix
    ./fuzzel.nix
    ./fnott.nix    
  ];
}
