{ ... }:

{
  boot.extraModprobeConfig = "options vfio-pci ids=1002:73a5,1002:ab28";
  boot.kernel.sysctl = {
    "vm.nr_hugepages" = 0;
    "vm.nr_overcommit_hugepages" = 15258;
  };
  boot.kernelParams = [
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
  boot.extraModulePackages = [config.boot.kernelPackages.ddcci-driver];
}
