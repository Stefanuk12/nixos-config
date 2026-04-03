{ pkgs, ... }:

let
  autovirt_amd = {
    main = pkgs.substitute {
      src = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/Scrut1ny/AutoVirt/refs/heads/main/patches/QEMU/Archive/amd-qemu-10.1.1.patch";
        hash = "sha256-xCwEIDK6CTSDIUCzcTAaqg3DkNFUUwos4ULRC6TS6zw=";
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
      url = "https://raw.githubusercontent.com/Scrut1ny/AutoVirt/refs/heads/main/patches/QEMU/Archive/libnfs6-qemu-10.1.1.patch";
      hash = "sha256-8DYaDJgNqjExUfEF9NMAv/IpmsJTDeGebQuk3r2F6BQ=";
    };
  };
  qemuSpoof = builtins.readFile ./qemu-spoof.sh;
  patched-qemu = pkgs.qemu_kvm.overrideAttrs (
    finalAttrs: previousAttrs: {
      patches = [
        autovirt_amd.main
        autovirt_amd.libnfs6
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
    }
  );
in
{
  virtualisation.libvirtd = {
    allowedBridges = [
      "nm-bridge"
      "virbr0"
    ];
    qemu = {
      package = patched-qemu;
    };
  };

  environment.systemPackages = [ patched-qemu ];
}
