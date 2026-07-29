{ lib, pkgs, ... }:

let
  hw = import ../../../hosts/home/hardware-profile.nix;
in
{
  imports = [
    ./hyprland.nix
    ./login.nix
  ];

  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "gpu-symlinks";
      text = ''
        KERNEL=="card*", KERNELS=="${hw.dgpu.pciAddr}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/rtx5080"
        KERNEL=="card*", KERNELS=="${hw.igpu.pciAddr}", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
      '';
      destination = "/etc/udev/rules.d/70-gpu-symlinks.rules";
    }
  );

  services.xserver.enable = true;
  services.xserver.xkb.extraLayouts.iso_us = {
    description = "US with ISO keys";
    languages = [ "eng" ];
    symbolsFile = pkgs.writeText "iso_us" ''
      xkb_symbols "intl" {
        include "us(basic)"
        key <BKSL> {[ numbersign, asciitilde ]};
        key <LSGT> {[ backslash, bar ]};
      };
    '';
  };
}
