{ lib, ... }:

let
  allowUnfreesP = pkg: builtins.elem (lib.getName pkg) [
    "corefonts"
    "vista-fonts"
    "spotify"
  ];
in {
  imports = [
    ./other
    ./virtualisation
  ];

  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
}