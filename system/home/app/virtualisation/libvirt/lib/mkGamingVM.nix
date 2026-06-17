# Shared config builder for the hardened GPU-passthrough Windows gaming VMs
# (win11-base/rblx/rblx-2). Returns the pure-data attrset that mkWindowsVM
# and the qemu hook consume; callers pass only the per-VM identity and the
# few fields that actually differ.
#
# Each VM shares the same CPU pinning, GPU, Looking Glass /dev/kvmfr0 and (by
# default) nvram/disk paths, so do NOT run two at once.

{ inputs, pkgs }:

let
  pinning = import ./pinning.nix;
in

{ name
, uuid
, diskFile
, serial
, mac
, varsPath ? /var/lib/libvirt/qemu/nvram/win11_VARS.fd
, memory ? 8
, hugepages ? { enable = true; size = 2; unit = "M"; }   # 2MB on-demand pages
, evdev ? [ ]                                             # direct host input passthrough; see win11-base for the shape
}:

{
  inherit name uuid memory hugepages evdev;

  cpu = {
    cores = 6;
    threads = 2;
    clusters = 1;
    pinTo = pinning.vmCores;
    hostCores = pinning.hostCores;
    features = {
      # svm (AMD virt), topoext, invtsc (stable guest TSC).
      require = [ "svm" "topoext" "invtsc" ];
      # Concealment: hypervisor bit + spectre-mitigation MSRs that leak
      # virt context. Add "rdtscp" here if using a patched kernel.
      disable = [
        "vmx-vnmi" "hypervisor"
        "ssbd" "amd-ssbd" "virt-ssbd"
        "rdpid"
      ];
    };
  };

  firmware = {
    code = "/var/lib/barely-metal/firmware/OVMF_CODE.fd";
    varsTemplate = "/var/lib/barely-metal/firmware/OVMF_VARS.fd";
    inherit varsPath;
    secureBoot = true;
  };

  hardening = {
    enable = true;
    emulator = "${inputs.barely-metal.packages.${pkgs.stdenv.hostPlatform.system}.qemu-patched}/bin/qemu-system-x86_64";
    smbios = "/var/lib/barely-metal/firmware/smbios.bin";
    acpiTable = "/var/lib/barely-metal/firmware/acpi/spoofed_devices.aml";
  };

  disks = [{
    file = diskFile;
    format = "qcow2";
    inherit serial;
    boot = 1;
  }];

  cdroms = [{
    file = "/var/lib/barely-metal/firmware/guest-scripts.iso";
  }];

  gpu = {
    addresses = [
      { bus = 3; slot = 0; function = 0; }
      { bus = 3; slot = 0; function = 1; }
    ];
  };

  lookingGlass = {
    enable = true;
    memSize = 67108864;  # 64MB → 1080p HDR / 1440p SDR
  };

  network = {
    bridge = "br0";
    inherit mac;
    model = "e1000e";
    pciBus = 10;
  };

  audio = {
    backend = "pipewire";
    uid = 1000;
  };

  tpm = true;
  spice = true;

  # CPU governor settings for the libvirt qemu hook.
  governor = {
    enable = true;
    active = "performance";   # Set on VM start
    restore = "schedutil";    # Restored on VM stop
  };
}
