# OSX-KVM macOS domain builder — shared by ../vms/osx-kvm.nix (no GPU,
# 4-vCPU) and ../vms/osx-kvm-gpu.nix (vfio passthrough + 12-vCPU pinning).
# Caller supplies `osxKvm` (the osx-kvm flake's `lib.mkOsxKvm` toolkit),
# evaluated once in domains.nix and threaded through.
#
# Both variants share the same disk images, so only one can run at a time
# (libvirt holds the qcow2 lock). Doesn't use ./mkWindowsVM.nix — that's a
# hardened anti-detection builder for Windows whose quirks don't fit macOS.
#
# Non-obvious bits:
#   * pkgs.qemu_kvm, NOT the system default emulator — the latter is
#     barely-metal's patched qemu whose PCI/LPC patches hang OSX-KVM's
#     macOS-OVMF in DXE init.
#   * Both OVMF pflash files MUST live outside /nix/store, else libvirt's
#     firmware-descriptor matcher silently swaps in stock OVMF (no macOS
#     patches, won't boot).
#   * 4M-format VARS (paired with OVMF_CODE_4M); the 128 KB legacy VARS
#     break libvirt's -blockdev pflash binding.

{ pkgs, osxKvm }:

{ name
, uuid
, memory   ? 4096                                       # MiB
, topology ? { sockets = 1; cores = 2; threads = 2; }
, pin      ? null                                       # { vmCores = [int]; hostCores = "..."; }
, hostdevs ? []                                         # [ { bus; slot; function; rom?; } ]  rom = "/path/to/vbios.rom" injects <rom file=…/>; needed when the device is the host's primary GPU and OVMF can't read its option ROM at VM start.
, spoofGpu ? null                                       # { aliasIdx; deviceId; }  decimal int (libvirt's unsigned parser rejects 0x… literals)
, evdev    ? []                                         # [ { dev; grab?; grabToggle?; repeat?; } ]
, portForwards ? []                                     # [ { proto = "tcp"|"udp"; from; to?; } ] forwarded host→guest on the slirp net
, profile         ? osxKvm.profiles.mp71                # SMBIOS profile attrset. Pick a built-in (osxKvm.profiles.{mp71,imac191}) or hand-build one — see osxKvm's default.nix header.
, extraKexts      ? [ ]                                 # Forwarded to osxKvm.mkImage; appended to profile.kexts and copied into EFI/OC/Kexts/.
, extraKextBlocks ? [ ]                                 # Forwarded to osxKvm.mkImage; merged into Kernel.Block by Identifier.
, extraAcpi       ? [ ]                                 # Forwarded to osxKvm.mkImage; .aml files copied into EFI/OC/ACPI/ and listed under ACPI.Add. Each entry: { name; source; comment?; }.
, drivers         ? osxKvm.opencore.defaultDrivers      # Forwarded to osxKvm.mkImage; explicit list of OpenCorePkg drivers (basenames) shipped in EFI/OC/Drivers AND listed in UEFI.Drivers.
, plistOverrides  ? { }                                 # Forwarded to osxKvm.mkImage; deep-merged onto the parsed config.plist last.
, runtimeDir      ? "/home/stefan/Documents/OSX-KVM"    # mutable host dir holding mac_hdd_ng.img + BaseSystem.img
, videos          ? [ { model.type = "vmvga"; } ]       # <video> list. Set [] to drop emulated video entirely (e.g. dGPU-only).
, darwinKvmStyle  ? false                               # Reshape the domain to match royalgraphx/DarwinKVM's reference XML (timers, nosharepages, itco watchdog, ACPI-hotplug-off, drop vmport, on_crash=restart). CPU model and <loader>/<nvram> stay locked to the OSX-KVM lineage.
}:

let
  # OpenCore image + OVMF come from the osx-kvm toolkit; user-data disks
  # (BaseSystem.img, mac_hdd_ng.img) and NVRAM stay in runtimeDir on real
  # disk since they can't live in /nix/store.
  ocImage = osxKvm.mkImage {
    inherit profile extraKexts extraKextBlocks extraAcpi drivers plistOverrides;
  };

  optionalAttrs = c: a: if c then a else {};
  optionals     = c: l: if c then l else [];

  # ── DarwinKVM-style reshapes (gated on darwinKvmStyle) ─────────────
  # All inert when the toggle is false. CPU mode and <loader>/<nvram> are
  # never touched here — they stay locked to the OSX-KVM lineage.

  # <memoryBacking><nosharepages/></memoryBacking> — DarwinKVM convention,
  # also discourages KSM merging (no real cost on a non-overcommitted host).
  darwinKvmDomainExtras = optionalAttrs darwinKvmStyle {
    memoryBacking.nosharepages = {};
  };

  # <bootmenu enable='yes'/> inside <os>. NOT setting firmware='efi' —
  # that triggers libvirt's firmware autoselection and silently swaps
  # OSX-KVM's macOS-patched OVMF for stock OVMF (won't boot).
  darwinKvmOsExtras = optionalAttrs darwinKvmStyle {
    bootmenu.enable = true;
  };

  # Full DarwinKVM timer set when the style is on; otherwise keep the
  # OSX-KVM-traditional minimal pair (hpet off, tsc native).
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

  # DarwinKVM's <features> is a bare <acpi/><apic/>; the OSX-KVM lineage
  # also disables <vmport> defensively. Drop it for parity when the
  # style is on.
  featuresSection =
    { acpi = { }; apic = { }; }
    // optionalAttrs (!darwinKvmStyle) { vmport = { state = false; }; };

  # DarwinKVM uses on_crash=restart; OSX-KVM defaulted to destroy.
  crashAction = if darwinKvmStyle then "restart" else "destroy";

  # <watchdog model='itco' action='none'/> — DarwinKVM emits this; pure
  # convention, doesn't reset on watchdog timeout.
  darwinKvmDeviceExtras = optionalAttrs darwinKvmStyle {
    watchdog = { model = "itco"; action = "none"; };
  };

  # QEMU 6.1+ requires turning off ACPI PCI hotplug-with-bridge-support
  # for the OpenCore-based macOS path; DarwinKVM's template prepends this
  # to qemu-commandline.arg.
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

  # GPU passthrough topology — single multifunction pcie-root-port with
  # both GPU functions on it (GPU = .0, HDMI audio = .1), as macOS's
  # AMDRadeonX6000 expects and real Mac Pros expose; split/high-slot
  # root-ports make macOS skip the device.
  #
  # Slot 1 = PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0), the standard
  # MacPro7,1 GPU slot path that AGPM and System Information key off;
  # non-standard slots make the GPU invisible there.
  #
  # No explicit <alias>: user-supplied alias names need a "ua-" prefix or
  # get renamed, so spoofGpu.aliasIdx keys off the auto-generated
  # "hostdev0"/"hostdev1" (declaration order).
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

  # Direct host input passthrough via QEMU's input-linux backend — lower
  # latency than emulated USB, and grab="all" gives the guest exclusive
  # access (toggle keys release it back to the host).
  mkEvdev = e:
    let hasGrab = e ? grab || e ? grabToggle || e ? repeat;
    in {
      type = "evdev";
      source =
        { inherit (e) dev; }
        // optionalAttrs (e ? grab)       { inherit (e) grab; }
        // optionalAttrs (e ? grabToggle) { inherit (e) grabToggle; }
        // optionalAttrs (e ? repeat)     { inherit (e) repeat; };
    };

  baseQemuArgs = [
    # Apple SMC emulation — OSX-KVM's OpenCore.qcow2 expects QEMU's
    # isa-applesmc rather than VirtualSMC.kext.
    { value = "-device"; }
    { value = "isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"; }
    { value = "-smbios"; }
    { value = "type=2"; }
    # Override libvirt's -cpu (last -cpu wins) to add +invtsc and
    # vmware-cpuid-freq=on — macOS-required quirks libvirt's <cpu> can't
    # express. Stay on Skylake-Client: the installed macOS's prelinked
    # kernel cache panics on Penryn.
    { value = "-cpu"; }
    { value = "Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on"; }
  ];

  # Bump OVMF's 64-bit PCI MMIO window to 64 GiB so it can map Navi 21's
  # 16 GiB resizable BAR; without the headroom macOS never sees the GPU.
  # GPU passthrough only.
  mmio64Args = optionals hasGpu [
    { value = "-fw_cfg"; }
    { value = "name=opt/ovmf/X-PciMmio64Mb,string=65536"; }
  ];

  # Net via qemu-commandline only when port forwards are needed (else
  # libvirt's <interface> handles it). Slirp's hostfwd takes no ranges, so
  # each range expands to one hostfwd= per port; same MAC/PCI address as
  # the libvirt path so the guest sees no difference.
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

  # Spoof a hostdev's PCI device-id (e.g. 6950 XT → 6900 XT) via
  # <qemu:override>, targeting libvirt's auto-generated "hostdev<N>" alias
  # (N = index in `hostdevs`). Uses <qemu:override> rather than -set,
  # which fails against libvirt's JSON-syntax -device emission.
  spoofOverride = optionalAttrs (spoofGpu != null) {
    qemu-override.device = {
      alias = "hostdev${toString spoofGpu.aliasIdx}";
      frontend.property = [
        { name = "x-pci-device-id"; type = "unsigned"; value = toString spoofGpu.deviceId; }
      ];
    };
  };

  # The libvirt domain attrset (consumed by nixvirt's writeXML). A let
  # binding rather than returned directly so it can sit alongside
  # `configPlist` in the outer attrset — callers want both.
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
      # OpenCore image is in /nix/store, so opened RO; libvirt rejects
      # readonly on SATA, hence virtio-blk. macOS ignores it after UEFI
      # handoff, so the bus mismatch with the SATA data disks is harmless.
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
      # Pin qemu-xhci to pcie.0 directly so libvirt doesn't auto-create
      # a pcie-pci-bridge to hang it from.
      {
        type = "usb"; index = 0; model = "qemu-xhci";
        address = { type = "pci"; domain = 0; bus = 0; slot = 5; function = 0; };
      }
      { type = "sata"; index = 0; }
      { type = "pci";  index = 0; model = "pcie-root"; }
    ] ++ gpuControllers;

    # User-mode (slirp NAT) virtio-net-pci — macOS recovery lacks e1000e
    # drivers but OpenCore.qcow2 ships virtio-net kexts, and slirp needs no
    # bridge. Internet is required to install macOS.
    #
    # With portForwards set, the netdev moves to qemu-commandline instead:
    # nixvirt's <interface> can't express <portForward>, and two netdevs
    # would collide on id.
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
  # Default profile (vmvga) keeps SPICE so OpenCore and early macOS are
  # visible before the AMD kexts claim the passthrough dGPU. Pure-
  # passthrough variants pass videos = [{ model.type = "none"; }], which
  # drops the emulated adapter and skips SPICE (nothing to render).
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
