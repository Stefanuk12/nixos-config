{ config, ... }:

{
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  # exclusive_caps=1 lets Chromium/Electron apps (Vesktop, Discord) recognize the loopback as a webcam.
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"
  '';
}