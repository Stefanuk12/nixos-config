{ pkgs, inputs, ... }:

{
  imports = [
    inputs.hydenix.nixosModules.default

    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  hydenix = {
    enable = true;
    hostname = "home";
    timezone = "Europe/London";
    locale = "en_GB.UTF-8";

    boot.enable = false;
    network.enable = false;
  };

  services.displayManager.sddm.wayland.compositorCommand = "kwin_wayland --drm-device=/dev/dri/card0";
}