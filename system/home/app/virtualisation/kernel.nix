{
  pkgs,
  config,
  lib,
  ...
}:
let
  kernelPatches = {
    svm = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/AutoVirt/refs/heads/main/patches/Kernel/Archive/linux-6.18.8-svm.patch";
      hash = "sha256-zz18xerutulLGzlHhnu26WCY8rVQXApyeoDtCjbejIk=";
    };
  };
in
{
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;
  # Disabled - current patches mess up CPU frequency, purely visual though
  # boot.kernelPatches = [
  #   {
  #     name = "autovirt-svm";
  #     patch = kernelPatches.svm;
  #   }
  # ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1002:73a5,1002:ab28
    options kvm_amd nested=1
    softdep amdgpu pre: vfio-pci
  '';
  boot.kernelParams = [
    # "amdgpu.dc=0"
    # "radeon.modeset=0"
    "amdgpu.ppfeaturemask=0xf7fff"
    "iommu=pt"
    "kvm.ignore_msrs=1"
    "vfio-pci.ids=1002:73a5,1002:ab28"
    # Hugepages allocated dynamically by libvirt qemu hook (see qemu/hooks.nix)
    "default_hugepagesz=1G"
    "hugepagesz=1G"
  ];
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"

    "i2c_dev"
    "ddcci_backlight"
  ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.ddcci-driver
  ];
}
