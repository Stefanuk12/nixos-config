{ pkgs, ... }:

let
  isoUsFile = pkgs.writeText "iso_us"
  ''
  xkb_symbols "intl" {
    include "us(basic)"

    key <BKSL> {[ numbersign, asciitilde ]};
    key <LSGT> {[ backslash, bar ]};
  };
  '';
in {
  environment.systemPackages = with pkgs; [
    waydroid
  ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    enableHidpi = true;
  };

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
}
