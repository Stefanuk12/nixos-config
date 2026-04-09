{ pkgs, ... }:

{
  home.packages = with pkgs.userPkgs; [
    grimblast
  ];

  wayland.windowManager.hyprland.settings.bind = [
    ", Print, exec, grimblast copy area"
  ];
}
