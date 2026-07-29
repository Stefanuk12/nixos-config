# Shared config builder for the hardened GPU-passthrough Windows gaming VMs (win11-base/rblx/rblx-2); they share CPU pinning, GPU, Looking Glass /dev/kvmfr0 and default nvram/disk paths, so never run two at once.

{ config }:

let
  pinning = import ./pinning.nix;
  hw = import ../../../../../../hosts/home/hardware-profile.nix;
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
, hardened ? true                                        # false = VR/perf profile (Hyper-V on, hypervisor visible, stock qemu for SteamVR)
, usb ? [ ]                                               # USB passthrough by id, e.g. [ { vendor = 1356; product = 3294; } ]
}:

{
  inherit name uuid memory hugepages evdev;
  usb = { devices = usb; };

  cpu = {
    cores = 6;
    threads = 2;
    clusters = 1;
    pinTo = pinning.vmCores;
    hostCores = pinning.hostCores;
    features = {
      require = [ "svm" "topoext" "invtsc" ];
      # Hides the hypervisor bit + the spectre MSRs that leak virt context. The VR profile keeps
      # them visible for Hyper-V enlightenments.
      disable = if hardened then [
        "vmx-vnmi" "hypervisor"
        "ssbd" "amd-ssbd" "virt-ssbd"
        "rdpid"
      ] else [ ];
    };
  };

  firmware = {
    code = "${config.barelyMetal.ovmfPackage}/FV/OVMF_CODE.fd";
    # Host-SB-key-injected vars from the activation; the store vars carry no host keys.
    varsTemplate = config.barelyMetal.ovmfVarsPath;
    inherit varsPath;
    secureBoot = true;
  };

  # When hardened = false, mkWindowsVM ignores emulator/smbios/acpiTable and falls back to stock qemu with Hyper-V enlightenments on.
  hardening = {
    enable = hardened;
    emulator = "${config.barelyMetal.qemuPackage}/bin/qemu-system-x86_64";
    smbios = config.barelyMetal.smbiosBinPath;
    acpiTable = "${config.barelyMetal.acpiTablesPackage}/spoofed_devices.aml";
  };

  disks = [{
    file = diskFile;
    format = "qcow2";
    inherit serial;
    boot = 1;
  }];

  cdroms = [{
    file = "${config.barelyMetal.guestScriptsIsoPackage}";
  }];

  gpu = {
    addresses = [
      { bus = hw.dgpu.busInt; slot = 0; function = 0; }
      { bus = hw.dgpu.busInt; slot = 0; function = 1; }
    ];
    # OVMF needs the GOP image to init the card as its console when video=none, else it hangs
    # during enumeration. Re-dump on a swap:
    #   echo 1 > /sys/bus/pci/devices/0000:01:00.0/rom; cat rom > vbios.rom; echo 0 > rom
    romFile = ../../vbios-rtx5080.rom;
  };

  lookingGlass = {
    enable = true;
    memSize = 134217728;  # 128MB → 4K HDR
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

  governor = {
    enable = true;
    active = "performance";
    restore = "schedutil";
  };
}
