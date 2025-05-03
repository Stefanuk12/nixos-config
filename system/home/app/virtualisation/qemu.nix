{pkgs, ...}: let
  # special anti-detection emulator
  hypervisor-phantom_amd = {
    main = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/QEMU/amd-qemu-9.2.0.patch";
      hash = "sha256-ZnlutMy9HqOmFV4xkO2r0yj5tEZMyTfg6nAWrX5xxc0=";
    };
    libnfs6 = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/QEMU/qemu-9.2.0-libnfs6.patch";
      hash = "sha256-HjZbgwWf7oOyvhJ4WKFQ996e9+3nVAjTPSzJfyTdF+4=";
    };
  };
  qemuSpoof = builtins.readFile ./qemu-spoof.sh;
  patched-qemu = pkgs.qemu.overrideAttrs (finalAttrs: previousAttrs: {
    patches = [hypervisor-phantom_amd.main hypervisor-phantom_amd.libnfs6];
    postPatch = ''
      ${previousAttrs.postPatch}
      CPU_VENDOR=amd
      QEMU_VERSION=9.2.0
      MANUFACTURER="Advanced Micro Devices, Inc."
      echo "applying dynamic patches"
      ${qemuSpoof}
    '';
  }); 
in {
  # ref: https://github.com/NixOS/nixpkgs/issues/115996
  virtualisation.libvirtd = {
    allowedBridges = ["nm-bridge" "virbr0"];
    qemu = {
      package = patched-qemu;
    };
  };

  environment.systemPackages = [patched-qemu];
}
