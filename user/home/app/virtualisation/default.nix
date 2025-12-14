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
    nvram = ["/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd:/run/libvirt/nix-ovmf/edk2-i386-vars.fd"]
  '';

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = ["qemu:///system"];
      uris = ["qemu:///system"];
    };
  };
}
