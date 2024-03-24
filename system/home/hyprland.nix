{ pkgs, ... }:

{
  imports = [
    ./wayland.nix
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };
}
