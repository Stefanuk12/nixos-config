{ config, pkgs, ... }:

{
  # Various packages related to virtualization, compatability and sandboxing
  home.packages = with pkgs; [
    # Virtual Machines and wine
    libvirt
    virt-manager
    qemu
    uefi-run
    lxc
    swtpm
    bottles
    quickemu

    # Filesystems
    dosfstools
  ];

  home.file.".config/libvirt/qemu.conf".text = ''
    nvram = ["${pkgs.OVMF.fd}/FV/OVMF_CODE.fd:${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"]
  '';

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
}
