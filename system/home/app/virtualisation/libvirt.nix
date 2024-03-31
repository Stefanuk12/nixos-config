
{ pkgs, ... }:

{
  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = [ "eth0" ];
    };
  };

  virtualisation.libvirtd = {
    enable = true;
    qemuVerbatimConfig = ''
      nvram = [
        "/nix/store/v9x2ya2q7h001k70qwdpgsp6cnhwm6g8-OVMF-202402-fd/FV/OVMF_VARS.fd"
      ]
    '';
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [pkgs.OVMFFull.fd];
      };
    };
  };

  boot.kernelParams = [
    "amd_iommu=on"
    "amd_iommu=pt"
    "kvm.ignore-msrs=1"
    "vfio-pci.ids=1002:73a5,1002:ab28"
  ];
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  users.groups.libvirtd.members = [ "root" "stefan" ];
}
