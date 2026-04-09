{ config, pkgs, ... }:

{
  imports = [
    ./looking_glass_client.nix
  ];

  home.packages = with pkgs.userPkgs; [
    libvirt
    virt-manager
    qemu
    uefi-run
    lxc
    swtpm
    bottles
    quickemu
    dosfstools
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
