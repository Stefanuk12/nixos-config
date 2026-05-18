{ config, ... }:

{
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  # exclusive_caps=1 is required for Chromium/Electron apps (Vesktop, Discord)
  # to recognize the loopback as a webcam.
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"
  '';
}