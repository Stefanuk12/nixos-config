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

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  # nixpkgs.config.allowUnfreePredicate = lib.mkDefault allowUnfreesP;
}
