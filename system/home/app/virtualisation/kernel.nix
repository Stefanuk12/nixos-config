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
  boot.kernelPatches = [
    # Disabled - current patches mess up CPU frequency, purely visual though
    # {
    #   name = "autovirt-svm";
    #   patch = kernelPatches.svm;
    # }
  ];
  boot.extraModprobeConfig = ''
    options vfio-pci ids=1002:73a5,1002:ab28
    options kvm_amd nested=1
    softdep amdgpu pre: vfio-pci
    options v4l2loopback exclusive_caps=1 card_label="OBS Virtual Camera"
  '';
  boot.kernelParams = [
    # "amdgpu.dc=0"
    # "radeon.modeset=0"
    "amdgpu.ppfeaturemask=0xf7fff"
    "iommu=pt"
    "kvm.ignore_msrs=1"
    "video=efifb:off"
    "vfio-pci.ids=1002:73a5,1002:ab28"
    # Force dGPU's HDMI-A-2 dummy plug disconnected so Hyprland doesn't
    # bind card0 when the dGPU rebinds to amdgpu post-boot. Verify with
    # cat /sys/class/drm/card0-HDMI-A-2/status.
    "video=HDMI-A-2:d"
    # 2MB hugepages allocated on-demand via vm.nr_overcommit_hugepages
    # (set by domains.nix); 2MB is the x86_64 default, no kernel params.
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
