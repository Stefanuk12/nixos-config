{ config, pkgs, ... }:

{
  imports = [
    ./hooks.nix
  ];

  virtualisation.libvirtd.qemu.swtpm.enable = true;
}
