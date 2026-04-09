{ inputs, ... }:

{
  imports = [
    inputs.hydenix.inputs.home-manager.nixosModules.home-manager
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
}