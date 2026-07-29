{ config, ... }:

{
  imports = [
    ./osd_placement.nix
    ./hyprland.nix
    ./noctalia.nix
    ./theme.nix
  ];
}
