{
  pkgs,
  config,
  lib,
  ...
}:
{
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest; # in-tree btmtk MT6639 (MT7927 BT) lands in 7.1
  # vfio-pci ids come from barelyMetal.vfio; the softdeps keep nvidia/nouveau off the dGPU first.
  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
    options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"

    softdep nvidia pre: vfio-pci
    softdep nouveau pre: vfio-pci
    softdep drm pre: vfio-pci
  '';
  boot.kernelParams = [
    # IOMMU (amd_iommu=on iommu=pt) and vfio-pci.ids come from barelyMetal.vfio
    "video=HDMI-A-2:d"
  ];
  boot.initrd.kernelModules = [
    # vfio_pci/vfio/vfio_iommu_type1 in initrd come from barelyMetal.vfio (earlyBinding)
    "i2c_dev"
    "ddcci_backlight"
  ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.ddcci-driver
  ];
}
