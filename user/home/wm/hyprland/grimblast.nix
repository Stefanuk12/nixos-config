{ pkgs, ... }:

{
  home.packages = with pkgs; [
    grimblast
  ];

  wayland.windowManager.hyprland.settings.bind = [
    ", Print, exec, grimblast copy area"
  ];
}
