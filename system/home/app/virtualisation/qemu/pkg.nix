{ pkgs, ... }:

let
  hypervisor-phantom_amd = {
    main = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/QEMU/amd-qemu-10.0.2.patch";
      hash = "sha256-eZOH00WZQ7nDF+yny01vYrvmpPlrH6cGxtxL/QxNE7g=";
    };
    libnfs6 = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/QEMU/libnfs6-qemu-10.0.2.patch";
      hash = "sha256-8DYaDJgNqjExUfEF9NMAv/IpmsJTDeGebQuk3r2F6BQ=";
    };
    cpu = builtins.readFile ./cpu.patch;
  };
  qemuSpoof = builtins.readFile ./qemu-spoof.sh;
  patched-qemu = pkgs.qemu.overrideAttrs (finalAttrs: previousAttrs: {
    nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [ pkgs.hexdump ];
    patches = [
      hypervisor-phantom_amd.main
      ./cpu.patch
      hypervisor-phantom_amd.libnfs6
    ];
    postPatch = ''
      ${previousAttrs.postPatch}
      CPU_VENDOR=amd
      QEMU_VERSION=10.0.0
      MANUFACTURER="Advanced Micro Devices, Inc."
      echo "applying dynamic patches"

      manufacturer="Advanced Micro Devices, Inc." # sudo dmidecode --string processor-manufacturer
      chassis_type="Desktop" # sudo dmidecode --string chassis-type
      ${qemuSpoof}
    '';
  });
in {
  virtualisation.libvirtd = {
    allowedBridges = ["nm-bridge" "virbr0"];
    qemu = {
      package = patched-qemu;
    };
  };

  environment.systemPackages = [patched-qemu];
}
