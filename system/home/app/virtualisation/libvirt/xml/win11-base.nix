# VM configuration — consumed by mkVM (domain XML) and mkQemuHook (CPU governor).
# This file is pure data; xml.nix handles the actual building.

{ inputs, pkgs }:

{
  name = "win11-base";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f32";

  memory = 16;
  hugepages = {
    enable = true;
    size = 1;       # 1GB pages (allocated dynamically by qemu hook)
    unit = "G";
  };

  cpu = {
    cores = 6;
    threads = 2;
    clusters = 1;
    pinTo = [ 2 10 3 11 4 12 5 13 6 14 7 15 ];
    hostCores = "0-1,8-9";
    features = {
      # OPTIMIZATION: svm (AMD hardware virt), topoext (topology extensions),
      #               invtsc (invariant TSC for stable guest timekeeping)
      require = [ "svm" "topoext" "invtsc" ];
      # CONCEALMENT: hypervisor (CPUID.1:ECX[31]), ssbd/amd-ssbd/virt-ssbd
      #              (spectre mitigations that leak virt context), rdpid
      # Add "rdtscp" here if using a patched kernel
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
    varsPath = /var/lib/libvirt/qemu/nvram/win11_VARS.fd;
    secureBoot = true;
  };

  hardening = {
    enable = true;
    emulator = "${inputs.barely-metal.packages.${pkgs.system}.qemu-patched}/bin/qemu-system-x86_64";
    smbios = "/var/lib/barely-metal/firmware/smbios.bin";
    acpiTable = "/var/lib/barely-metal/firmware/acpi/spoofed_devices.aml";
    # acpiBattery = "/path/to/SSDT-battery.aml";
    # enforcePvCpuid = true;  # Closes MSR-probing vector but can crash guests
  };

  disks = [{
    file = /var/lib/libvirt/images/win11-base.qcow2;
    format = "qcow2";
    serial = "ECFE037C590CE21A24AE";
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
    mac = "52:54:3a:20:c8:5d";
    model = "e1000e";
    pciBus = 10;
  };

  audio = {
    backend = "pipewire";
    uid = 1000;
  };

  tpm = true;
  spice = true;

  # Direct host input passthrough via evdev — lower latency than USB.
  # Only needed on first install / when Looking Glass Host is NOT
  # installed on the guest. Find devices with: ls -l /dev/input/by-id/
  evdev = [
    { dev = "/dev/input/event1"; }                                        # keyboard
    { dev = "/dev/input/event6"; grab = "all"; grabToggle = "ctrl-ctrl";  # mouse
      repeat = true; }
  ];

  # CPU governor settings for the libvirt qemu hook
  governor = {
    enable = true;
    active = "performance";   # Set on VM start
    restore = "schedutil";    # Restored on VM stop
  };
}