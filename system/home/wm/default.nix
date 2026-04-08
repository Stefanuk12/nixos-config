{ pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./wayland.nix
  ];

  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];
}
