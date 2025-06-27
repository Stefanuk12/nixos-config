{ pkgs, config, lib, ... }:
let
  kernelPatches = {
    svm = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/Kernel/linux-6.13-svm.patch";
      hash = "sha256-zz18xerutulLGzlHhnu26WCY8rVQXApyeoDtCjbejIk=";
    };
  };
in {
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_14;
  # Disabled - current patches mess up CPU frequency, purely visual though
  # boot.kernelPatches = [
  #   {
  #     name = "hypervisor-phantom-svm";
  #     patch = kernelPatches.svm;
  #   }
  # ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1002:73a5,1002:ab28
    options kvm_amd nested=1
  '';
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 0;
    "vm.nr_overcommit_hugepages" = 15258;
  };
  boot.kernelParams = [
    # "amdgpu.dc=0"
    # "radeon.modeset=0"
    "iommu=pt"
    "kvm.ignore-msrs=1"
    "kvmfr.static_size_mb=32"
  ];
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
    "kvmfr"

    "i2c_dev"
    "ddcci_backlight"
  ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.ddcci-driver
    pkgs.linuxKernel.packages.linux_6_14.kvmfr
  ];
}
