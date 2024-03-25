{ config, pkgs, ... }:

{
  imports = [
    ./libvirt.nix
  ];

  programs = {
    dconf.enable = true;
    virt-manager.enable = true;
  };

  environment.systemPackages = with pkgs; [ virt-manager virtualbox distrobox ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ virtualbox ];
}
