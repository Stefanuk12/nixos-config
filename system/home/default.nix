{config, ...}: {
  imports = [
    ./wm
    ./hyprland.nix
    ./lanzaboote.nix
    ./app/virtualisation
  ];
}
