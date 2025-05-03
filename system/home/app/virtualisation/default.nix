{ config, pkgs, ... }:

{
  imports = [
    ./libvirt.nix
    ./kernel.nix
    ./kvmfr.nix
    ./looking_glass.nix
    ./qemu_hooks.nix
    ./edk2.nix
  ];

  programs = {
    dconf.enable = true;
    virt-manager.enable = true;
  };

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
