{ pkgs, ... }:

let
  hypervisor-phantom_amd = {
    main = pkgs.substitute {
      src = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/patches/QEMU/amd-qemu-10.1.1.patch";
        hash = "sha256-dIS6nSiMe+r+mWHu8WeFUowEfR5uDlvwtA7KA7tzCCQ=";
      };
      substitutions = [
        "--replace-fail"
        "AMD Ryzen 7 7700X 8-Core Processor"
        "AMD Ryzen 7 7600X 6-Core Processor"
        "--replace-fail"
        ''0x1022 // "Red Hat, Inc."''
        ''0x1b36 // "Red Hat, Inc."''
      ];
    };
    libnfs6 = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/patches/QEMU/libnfs6-qemu-10.1.1.patch";
      hash = "sha256-8DYaDJgNqjExUfEF9NMAv/IpmsJTDeGebQuk3r2F6BQ=";
    };
  };
  qemuSpoof = builtins.readFile ./qemu-spoof.sh;
  patched-qemu = pkgs.qemu_kvm.overrideAttrs (finalAttrs: previousAttrs: {
    patches = [
      hypervisor-phantom_amd.main
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
