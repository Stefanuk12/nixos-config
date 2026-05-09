# OSX-KVM macOS domain builder — shared by ../vms/osx-kvm.nix (no GPU,
# default 4-vCPU profile) and ../vms/osx-kvm-gpu.nix (vfio passthrough +
# 12-vCPU pinning).
#
# Caller must supply `osxKvm` (the toolkit produced by the osx-kvm flake's
# `lib.mkOsxKvm`); domains.nix evaluates it once and threads it through.
#
# Both variants point at the same OSX-KVM disk images, so only one can
# run at a time (libvirt refuses the second start while the qcow2 lock
# is held).
#
# Doesn't go through ./mkWindowsVM.nix because that's a hardened/anti-detection
# builder for Windows guests (Hyper-V enlightenments off, kvm.hidden,
# msrs.unknown=fault, no virtual GPU, etc.) — none of which fit a macOS
# guest.
#
# The non-obvious bits:
#
#   * pkgs.qemu_kvm, NOT the system default emulator.
#     /run/libvirt/nix-emulators/qemu-system-x86_64 points at
#     barely-metal-qemu (the patched build for Windows anti-detection);
#     its PCI/LPC patches hang OSX-KVM's macOS-OVMF in DXE init. Stock
#     qemu_kvm boots fine. See git log of osx-kvm.nix (~May 2026) for
#     the full bisection if you ever need it.
#
#   * OSX-KVM ships its own macOS-patched OVMF. Both pflash files MUST
#     live outside /nix/store — libvirt's firmware-descriptor matcher
#     otherwise silently rewrites <loader> to nixpkgs stock OVMF, which
#     lacks the macOS patches and won't boot.
#
#   * 4M-format VARS (paired by size with OVMF_CODE_4M). The 128 KB
#     legacy VARS that OSX-KVM ships work with shell-style -drive
#     pflash but break libvirt's -blockdev pflash binding.

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
, darwinKvmStyle  ? false                               # Reshape the libvirt domain to match royalgraphx/DarwinKVM's reference XML (DarwinKVM.sh template): adds <memoryBacking nosharepages/>, <bootmenu enable=yes/> in <os>, full DarwinKVM clock timers (rtc/pit/hpet/tsc), <watchdog model='itco' action='none'>, prepends -global ICH9-LPC.acpi-pci-hotplug-with-bridge-support=off, drops <vmport>, switches on_crash to restart. CPU model and the explicit <loader>/<nvram> stay as-is — see the prelinked-kernel and OVMF-autoselection comments above for why.
}:

let
  # OpenCore.qcow2 + OVMF firmware come from the osx-kvm flake (caller
  # passes the toolkit in via `osxKvm`). Disks that hold actual user data
  # (BaseSystem.img, mac_hdd_ng.img) and per-VM NVRAM stay in runtimeDir
  # on real disk — they can't live in /nix/store.
  ocImage = osxKvm.mkImage {
    inherit profile extraKexts extraKextBlocks extraAcpi drivers plistOverrides;
  };

  optionalAttrs = c: a: if c then a else {};
  optionals     = c: l: if c then l else [];

  # ── DarwinKVM-style reshapes (gated on darwinKvmStyle) ─────────────
  # All inert when the toggle is false, so the no-GPU variant keeps its
  # current XML byte-for-byte. CPU mode and the explicit <loader>/<nvram>
  # are NOT touched here — they're locked by upstream comments above.

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

  # GPU passthrough topology — matches OSX-KVM's tested layout: a
  # single multifunction pcie-root-port with both GPU functions sharing
  # it (GPU = .0, HDMI audio = .1). macOS's AMDRadeonX6000 kext expects
  # a single multifunction PCIe device, which is what real Mac Pros
  # expose. Split root-ports at high slots (e.g. 0x10) caused macOS to
  # silently skip the device entirely.
  #
  # Slot 1 puts the dGPU at PciRoot(0x0)/Pci(0x1,0x0)/Pci(0x0,0x0) —
  # the standard MacPro7,1 GPU slot path. AGPM and System Information's
  # PCI tab key off Mac Pro slot paths; non-standard slots make the GPU
  # invisible there even when the kexts attach. (Earlier this lived at
  # slot 2 to avoid colliding with vmvga's auto-placed bridge at slot
  # 1; with vmvga removed in the GPU variant that constraint is gone.)
  #
  # No explicit <alias> on the hostdevs — libvirt's user-supplied alias
  # names require a "ua-" prefix and get renamed otherwise; the
  # auto-generated "hostdev0", "hostdev1" in declaration order is what
  # spoofGpu.aliasIdx keys off.
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

  # Direct host input passthrough — QEMU reads /dev/input/eventN via the
  # input-linux backend. Lower latency than emulated USB and lets the
  # guest grab the device exclusively (grab="all"). Toggle keys
  # (e.g. ctrl-ctrl) release the grab back to the host.
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
    # Override libvirt's -cpu Skylake-Client,mpx=off (last -cpu wins).
    # +invtsc and vmware-cpuid-freq=on are macOS-required quirks libvirt's
    # <cpu> can't express. Penryn was tried for AMD-passthrough parity
    # with OSX-KVM's reference, but the existing macOS install's
    # prelinked kernel cache panics on Penryn (built against Skylake's
    # AVX2/RDRAND). Stay on Skylake-Client unless reinstalling macOS.
    { value = "-cpu"; }
    { value = "Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on"; }
  ];

  # Bump OVMF's 64-bit PCI MMIO window from the default 32 GiB to 64 GiB.
  # Navi 21 (RX 6900/6950 XT) advertises a 16 GiB resizable framebuffer
  # BAR; with several other 64-bit BARs from emulated devices in the same
  # window, OVMF can fail to map the GPU's BARs cleanly and macOS then
  # never sees the device on the PCI tree (PCI section in System
  # Information shows nothing, AMDRadeonX6000 never binds). Only emit
  # when a GPU is being passed through — otherwise it's just noise.
  mmio64Args = optionals hasGpu [
    { value = "-fw_cfg"; }
    { value = "name=opt/ovmf/X-PciMmio64Mb,string=65536"; }
  ];

  # Net via qemu-commandline (only when port forwards are needed —
  # otherwise libvirt's <interface> handles it). Slirp's hostfwd doesn't
  # accept ranges inline, so we expand each range into one hostfwd= per
  # port. Same MAC + PCI address as the libvirt-managed path, so the
  # guest sees no observable difference.
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
  # <qemu:override>. Targets libvirt's auto-generated "hostdev<N>"
  # alias, where N is the index in the `hostdevs` list.
  #
  # NOTE: previously implemented with -set in <qemu:commandline>, but
  # newer libvirt emits -device in JSON syntax which bypasses qemu's
  # QemuOpts registry, so -set fails with "there is no device defined".
  # <qemu:override> rewrites the property on libvirt's emitted -device
  # directly and works with both comma- and JSON-syntax emission.
  spoofOverride = optionalAttrs (spoofGpu != null) {
    qemu-override.device = {
      alias = "hostdev${toString spoofGpu.aliasIdx}";
      frontend.property = [
        { name = "x-pci-device-id"; type = "unsigned"; value = toString spoofGpu.deviceId; }
      ];
    };
  };

  # The libvirt domain attrset (consumed by nixvirt's writeXML). Built as a
  # let-binding rather than returned directly so we can sit it alongside
  # `configPlist` in the outer attrset below — callers want both.
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
      # OpenCore image lives in /nix/store (read-only fs), so it must be
      # opened RO. libvirt rejects readonly on SATA, so this disk uses
      # virtio-blk. macOS never touches it after UEFI handoff, so the bus
      # mismatch with the SATA data disks below doesn't matter.
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

    # Network — User-mode (slirp NAT) virtio-net-pci, matching OSX-KVM's
    # working shell script. macOS recovery (BaseSystem) doesn't ship e1000e
    # drivers, but OSX-KVM's OpenCore.qcow2 includes the virtio-net kexts.
    # User-mode also avoids needing a bridge (bridges block guest internet
    # unless DHCP/NAT is set up explicitly). Internet is required to
    # install macOS — recovery downloads the OS image from Apple.
    #
    # When portForwards is set, the netdev is emitted via qemu-commandline
    # instead of libvirt's <interface> — nixvirt's interface schema doesn't
    # expose <portForward>, and we can't have both libvirt's auto-netdev
    # and a hostfwd-enabled one (id collision).
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
  # Default profile (vmvga) keeps SPICE wired up so OpenCore and early
  # macOS are visible before the AMD kexts claim a passthrough dGPU.
  # Pure-passthrough variants pass `videos = [{ model.type = "none"; }]`
  # — that emits <video><model type='none'/></video> so libvirt/QEMU
  # don't auto-add a fallback adapter, and SPICE is skipped because it
  # would have nothing to render.
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
