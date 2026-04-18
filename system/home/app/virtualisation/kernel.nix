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
    # Force dGPU's HDMI-A-2 (dummy plug) as disconnected so Hyprland
    # doesn't bind to card0 when the dGPU is rebound to amdgpu post-boot.
    # Verify with: cat /sys/class/drm/card0-HDMI-A-2/status (should read
    # "disconnected"). If connector names shift after hardware changes,
    # re-check against /sys/class/drm/.
    "video=HDMI-A-2:d"
    # Hugepages: using 2MB pages, allocated on-demand via
    # vm.nr_overcommit_hugepages (set by xml.nix). 2MB is the
    # default hugepage size on x86_64, no kernel params needed.
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
