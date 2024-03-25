{ config, pkgs, ... }:

{
  imports = [
    ./libvirt.nix
  ];

  environment.systemPackages = with pkgs; [ virt-manager virtualbox distrobox ];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };
  programs.virt-manager.enable = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [ virtualbox ];
}
