# OSX-KVM macOS domain builder shared by ../vms/osx-kvm{,-gpu}.nix; it uses pkgs.qemu_kvm (barely-metal's patched qemu hangs macOS-OVMF) and keeps both 4M-format OVMF pflash files outside /nix/store, else libvirt swaps in non-booting stock OVMF.

{ pkgs, osxKvm }:

{ name
, uuid
, memory   ? 4096                                       # MiB
, topology ? { sockets = 1; cores = 2; threads = 2; }
, pin      ? null                                       # { vmCores = [int]; hostCores = "..."; }
, hostdevs ? []                                         # [ { bus; slot; function; rom?; } ]; rom injects <rom file=…/> for the host's primary GPU whose option ROM OVMF can't read at start.
, spoofGpu ? null                                       # { aliasIdx; deviceId; }  decimal int (libvirt's unsigned parser rejects 0x… literals)
, evdev    ? []                                         # [ { dev; grab?; grabToggle?; repeat?; } ]
, portForwards ? []                                     # [ { proto = "tcp"|"udp"; from; to?; } ] forwarded host→guest on the slirp net
, profile         ? osxKvm.profiles.mp71                # SMBIOS profile; use a built-in (osxKvm.profiles.{mp71,imac191}) or hand-build one (see osxKvm's default.nix).
, extraKexts      ? [ ]                                 # Forwarded to osxKvm.mkImage; appended to profile.kexts and copied into EFI/OC/Kexts/.
, extraKextBlocks ? [ ]                                 # Forwarded to osxKvm.mkImage; merged into Kernel.Block by Identifier.
, extraAcpi       ? [ ]                                 # Forwarded to osxKvm.mkImage; each { name; source; comment?; } copies an .aml into EFI/OC/ACPI/ and lists it under ACPI.Add.
, drivers         ? osxKvm.opencore.defaultDrivers      # Forwarded to osxKvm.mkImage; explicit list of OpenCorePkg drivers (basenames) shipped in EFI/OC/Drivers AND listed in UEFI.Drivers.
, plistOverrides  ? { }                                 # Forwarded to osxKvm.mkImage; deep-merged onto the parsed config.plist last.
, runtimeDir      ? "/home/stefan/Documents/OSX-KVM"    # mutable host dir holding mac_hdd_ng.img + BaseSystem.img
, videos          ? [ { model.type = "vmvga"; } ]       # <video> list; set [] to drop emulated video (e.g. dGPU-only).
, darwinKvmStyle  ? false                               # Reshape the domain to match DarwinKVM's reference XML (timers, nosharepages, itco watchdog, hotplug-off, on_crash=restart); CPU model and <loader>/<nvram> stay OSX-KVM.
}:

let
  # OpenCore image + OVMF come from the osx-kvm toolkit; user-data disks and NVRAM stay in runtimeDir since they can't live in /nix/store.
  ocImage = osxKvm.mkImage {
    inherit profile extraKexts extraKextBlocks extraAcpi drivers plistOverrides;
  };

  optionalAttrs = c: a: if c then a else {};
  optionals     = c: l: if c then l else [];

  # ── DarwinKVM-style reshapes (gated on darwinKvmStyle) ─────────────
  # All inert when the toggle is false; CPU mode and <loader>/<nvram> stay locked to the OSX-KVM lineage.

  # <nosharepages/> — DarwinKVM convention that also discourages KSM merging.
  darwinKvmDomainExtras = optionalAttrs darwinKvmStyle {
    memoryBacking.nosharepages = {};
  };

  # <bootmenu enable='yes'/> in <os>; deliberately not firmware='efi', which would autoselect stock OVMF over OSX-KVM's patched build and fail to boot.
  darwinKvmOsExtras = optionalAttrs darwinKvmStyle {
    bootmenu.enable = true;
  };

  # Full DarwinKVM timer set when the style is on, else the OSX-KVM minimal pair (hpet off, tsc native).
  clockTimers =
    if darwinKvmStyle then [
      { name = "rtc";  tickpolicy = "catchup"; }
      { name = "pit";  tickpolicy = "delay"; }
      { name = "hpet"; present = true; }
      { name = "tsc";  present = true; mode = "native"; }
    ] else [
      { name = "hpet"; present = false; }
      { name = "tsc";  present = true; mode = "native"; }
    ];

  # DarwinKVM's <features> is a bare <acpi/><apic/>; OSX-KVM also disables <vmport>, dropped for parity when the style is on.
  featuresSection =
    { acpi = { }; apic = { }; }
    // optionalAttrs (!darwinKvmStyle) { vmport = { state = false; }; };

  # DarwinKVM uses on_crash=restart; OSX-KVM defaulted to destroy.
  crashAction = if darwinKvmStyle then "restart" else "destroy";

  # <watchdog model='itco' action='none'/> — DarwinKVM convention, doesn't reset on timeout.
  darwinKvmDeviceExtras = optionalAttrs darwinKvmStyle {
    watchdog = { model = "itco"; action = "none"; };
  };

  # QEMU 6.1+ needs ACPI PCI hotplug-with-bridge-support off for the OpenCore macOS path.
  darwinKvmQemuPrefix = optionals darwinKvmStyle [
    { value = "-global"; }
    { value = "ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off"; }
  ];

  hasPin = pin != null;
  hasGpu = hostdevs != [];

  vcpuCount =
    if hasPin
    then builtins.length pin.vmCores
    else topology.sockets * topology.cores * topology.threads;

  cputuneSection = optionalAttrs hasPin {
    cputune = {
      emulatorpin.cpuset = pin.hostCores;
      vcpupin = builtins.genList (i: {
        vcpu = i;
        cpuset = toString (builtins.elemAt pin.vmCores i);
      }) (builtins.length pin.vmCores);
    };
  };

  # Single multifunction pcie-root-port at slot 1 (GPU .0, HDMI audio .1) is the MacPro7,1 GPU path AMDRadeonX6000/AGPM expect — other slots hide the GPU — and no explicit <alias> is set so spoofGpu.aliasIdx keys off the auto-generated "hostdevN".
  gpuControllers = optionals hasGpu [{
    type = "pci"; index = 1; model = "pcie-root-port";
    address = { type = "pci"; domain = 0; bus = 0; slot = 1; function = 0; };
  }];

  mkHostdev = i: h:
    let isFirst = i == 0;
        isMulti = builtins.length hostdevs > 1;
    in {
      mode = "subsystem"; type = "pci"; managed = true;
      source.address = { domain = 0; inherit (h) bus slot function; };
      address = {
        type = "pci"; domain = 0; bus = 1; slot = 0; function = i;
      } // optionalAttrs (isFirst && isMulti) {
        multifunction = true;
      };
    } // optionalAttrs (h ? rom) {
      rom.file = h.rom;
    };

  # Direct host input passthrough via input-linux — lower latency than USB, and grab="all" gives the guest exclusive access.
  mkEvdev = e:
    {
      type = "evdev";
      source =
        { inherit (e) dev; }
        // optionalAttrs (e ? grab)       { inherit (e) grab; }
        // optionalAttrs (e ? grabToggle) { inherit (e) grabToggle; }
        // optionalAttrs (e ? repeat)     { inherit (e) repeat; };
    };

  baseQemuArgs = [
    # Apple SMC emulation — OSX-KVM's OpenCore.qcow2 expects isa-applesmc, not VirtualSMC.kext.
    { value = "-device"; }
    { value = "isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"; }
    { value = "-smbios"; }
    { value = "type=2"; }
    # Override libvirt's -cpu (last wins) for +invtsc and vmware-cpuid-freq=on; stay on Skylake-Client since the installed macOS panics on Penryn.
    { value = "-cpu"; }
    { value = "Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on"; }
  ];

  # Bump OVMF's 64-bit MMIO window to 64 GiB (GPU passthrough only) so it can map Navi 21's resizable BAR, else macOS never sees the GPU.
  mmio64Args = optionals hasGpu [
    { value = "-fw_cfg"; }
    { value = "name=opt/ovmf/X-PciMmio64Mb,string=65536"; }
  ];

  # Net via qemu-commandline only for port forwards (else libvirt's <interface> handles it); slirp hostfwd takes no ranges, so each range expands per-port with the same MAC/PCI address.
  expandRange = f:
    let to = if f ? to then f.to else f.from;
    in builtins.genList (i: { inherit (f) proto; port = f.from + i; }) (to - f.from + 1);
  hostfwdEntries = builtins.concatLists (map expandRange portForwards);
  hostfwdStr = builtins.concatStringsSep ","
    (map (e: "hostfwd=${e.proto}::${toString e.port}-:${toString e.port}") hostfwdEntries);
  netArgs = optionals (portForwards != []) [
    { value = "-netdev"; }
    { value = "user,id=osxnet0,${hostfwdStr}"; }
    { value = "-device"; }
    { value = "virtio-net-pci,netdev=osxnet0,mac=52:54:00:c9:18:27,bus=pcie.0,addr=0x6"; }
  ];

  # Spoof a hostdev's PCI device-id (e.g. 6950 XT → 6900 XT) via <qemu:override> on the auto "hostdev<N>" alias, since -set fails against libvirt's JSON -device emission.
  spoofOverride = optionalAttrs (spoofGpu != null) {
    qemu-override.device = {
      alias = "hostdev${toString spoofGpu.aliasIdx}";
      frontend.property = [
        { name = "x-pci-device-id"; type = "unsigned"; value = toString spoofGpu.deviceId; }
      ];
    };
  };

  # The libvirt domain attrset (for nixvirt's writeXML), a let binding so it can sit alongside configPlist since callers want both.
  domain =
{
  type = "kvm";
  inherit name uuid;

  memory        = { unit = "MiB"; count = memory; };
  currentMemory = { unit = "MiB"; count = memory; };

  vcpu = { placement = "static"; count = vcpuCount; };

  os = {
    type    = "hvm";
    arch    = "x86_64";
    machine = "q35";
    loader = {
      readonly = true;
      type     = "pflash";
      path     = "${osxKvm.ovmf.code}";
    };
    nvram = {
      template = "${osxKvm.ovmf.varsTemplate}";
      path     = "/var/lib/libvirt/qemu/nvram/${name}_VARS.fd";
    };
  } // darwinKvmOsExtras;

  features = featuresSection;

  cpu = {
    mode  = "custom";
    match = "exact";
    check = "none";
    model = { fallback = "allow"; name = "Skylake-Client"; };
    inherit topology;
  };

  clock = {
    offset = "utc";
    timer = clockTimers;
  };

  on_poweroff = "destroy";
  on_reboot   = "restart";
  on_crash    = crashAction;

  devices = {
    emulator = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";

    disk = [
      # OpenCore image is in /nix/store so opened RO; libvirt rejects readonly on SATA, hence virtio-blk (macOS ignores the bus after UEFI handoff).
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "qcow2";
        source.file = "${ocImage}";
        target = { dev = "vda"; bus = "virtio"; };
        readonly = {};
        boot.order = 1;
      }
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "raw";
        source.file = "${runtimeDir}/BaseSystem.img";
        target = { dev = "sdb"; bus = "sata"; };
      }
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "qcow2";
        source.file = "${runtimeDir}/mac_hdd_ng.img";
        target = { dev = "sdc"; bus = "sata"; };
      }
    ];

    controller = [
      # Pin qemu-xhci to pcie.0 directly so libvirt doesn't auto-create a pcie-pci-bridge for it.
      {
        type = "usb"; index = 0; model = "qemu-xhci";
        address = { type = "pci"; domain = 0; bus = 0; slot = 5; function = 0; };
      }
      { type = "sata"; index = 0; }
      { type = "pci";  index = 0; model = "pcie-root"; }
    ] ++ gpuControllers;

    # User-mode (slirp NAT) virtio-net-pci since macOS recovery lacks e1000e but ships virtio-net kexts; moves to qemu-commandline when portForwards is set, which nixvirt's <interface> can't express.
    interface = optionals (portForwards == []) [{
      type        = "user";
      mac.address = "52:54:00:c9:18:27";
      model.type  = "virtio";
      link.state  = "up";
      address = { type = "pci"; domain = 0; bus = 0; slot = 6; function = 0; };
    }];

    input = [
      { type = "keyboard"; bus = "usb"; }
      { type = "tablet";   bus = "usb"; }
    ] ++ (map mkEvdev evdev);

    sound      = { model = "ich9"; audio.id = 1; };
    audio      = { id = 1; type = "pipewire"; runtimeDir = "/run/user/1000"; };
    memballoon.model = "none";
    video = videos;
  }
  # vmvga keeps SPICE so OpenCore/early macOS are visible before the AMD kexts claim the dGPU; videos = [{ model.type = "none"; }] drops the adapter and SPICE.
  // optionalAttrs (builtins.any (v: v.model.type or "" != "none") videos) {
    graphics = {
      type = "spice"; autoport = true;
      listen = { type = "address"; address = "127.0.0.1"; };
    };
  } // optionalAttrs hasGpu {
    hostdev = builtins.genList
      (i: mkHostdev i (builtins.elemAt hostdevs i))
      (builtins.length hostdevs);
  } // darwinKvmDeviceExtras;

  qemu-commandline.arg = darwinKvmQemuPrefix ++ baseQemuArgs ++ mmio64Args ++ netArgs;
}
// cputuneSection
// spoofOverride
// darwinKvmDomainExtras;
in
{
  inherit domain;
  configPlist = ocImage.plist;
}
