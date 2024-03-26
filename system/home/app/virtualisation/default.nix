{ config, pkgs, ... }:

{
  imports = [
    ./libvirt.nix
  ];

  programs = {
    dconf.enable = true;
    virt-manager.enable = true;
  };

  # dconf.settings = {
  #   "org/virt-manager/virt-manager/connections" = {
  #     autoconnect = [ "qemu:///system" ];
  #     uris = [ "qemu:///system" ];
  #   };
  # };

  environment.systemPackages = with pkgs; [
    spice
    spice-gtk
    spice-protocol
    virt-manager
    virt-viewer
    virtio-win
    win-spice
    virtualbox
    distrobox
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ virtualbox ];

  virtualisation.spiceUSBRedirection.enable = true;
  services.spice-vdagentd.enable = true;
}
