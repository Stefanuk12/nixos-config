{
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    # Unset means keep ALL, which fills the 1.3G ESP and breaks bootloader installs; each
    # generation is ~165MB here.
    configurationLimit = 5;
  };
}
