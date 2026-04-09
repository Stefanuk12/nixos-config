{ pkgs, ... }:

{
  imports = [
    ./hyprland.nix
    ./wayland.nix

    ./hydenix.nix
  ];

  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];
}
