{ lib, inputs, pkgs, ... }:

let
  allowUnfreesP =
    pkg:
    builtins.elem (lib.getName pkg) [
      "corefonts"
      "vista-fonts"
      "spotify"
    ];
in
{
  imports = [
    ./gaming
    ./other
    ./virtualisation

    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
  }; 
}
