{ lib, pkgs, ... }:

let
  isoUsFile = pkgs.writeText "iso_us" ''
    xkb_symbols "intl" {
      include "us(basic)"

      key <BKSL> {[ numbersign, asciitilde ]};
      key <LSGT> {[ backslash, bar ]};
    };
  '';
in
{
  imports = [
    ./hydenix.nix
  ];

  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "gpu-symlinks";
      text = ''
        KERNEL=="card*", KERNELS=="0000:03:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/rx6950xt"
        KERNEL=="card*", KERNELS=="0000:0e:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
      '';
      destination = "/etc/udev/rules.d/70-gpu-symlinks.rules";
    }
  );

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "iso_us";
    variant = "intl";
    options = "caps:escape";
    extraLayouts.iso_us = {
      description = "ISO US";
      languages = [ "eng" ];
      symbolsFile = isoUsFile;
    };
  };

  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];
}
