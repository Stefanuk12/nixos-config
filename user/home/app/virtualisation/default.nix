{ config, pkgs, ... }:

{
  imports = [
    ./looking_glass_client.nix
    ./winapps
  ];

  home.packages = with pkgs; [
    libvirt
    virt-manager
    qemu
    uefi-run
    lxc
    swtpm
    quickemu
    dosfstools
    sshfs
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };
  };
}
