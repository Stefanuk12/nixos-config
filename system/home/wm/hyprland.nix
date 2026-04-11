{ pkgs, lib, ... }:

{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = lib.mkDefault pkgs.xdg-desktop-portal-hyprland;
  };
}
