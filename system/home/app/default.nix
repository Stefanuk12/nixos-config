{ lib, ... }:

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
    ./other
    ./virtualisation
    # ./home_manager.nix
  ];

  # nixpkgs.config.allowUnfreePredicate = lib.mkDefault allowUnfreesP;
}
