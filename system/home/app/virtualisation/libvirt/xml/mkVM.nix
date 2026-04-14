# mkVM.nix — Declarative libvirt domain builder
#
# Generates a full attribute set compatible with nixvirt's domain.writeXML.
# Supports hardened (anti-detection) and default VM profiles.
#
# References:
#   - https://libvirt.org/formatdomain.html
#   - https://github.com/Scrut1ny/AutoVirt/blob/main/modules/README.md
#   - https://docs.kernel.org/virt/kvm/x86/msr.html
#
# Usage:
#   let mkVM = import ./mkVM.nix;
#   in mkVM { name = "my-vm"; uuid = "..."; memory = 16; ... }

cfg:

let
  # ── Helpers ──────────────────────────────────────────────

  mkUnit = unit: count: { inherit unit count; };

  indexed = f: list:
    builtins.genList (i: f i (builtins.elemAt list i)) (builtins.length list);

  optionals = cond: list: if cond then list else [];
  optionalAttrs = cond: as: if cond then as else {};

  letters = [ "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" ];

  # ── Unpack config with defaults ──────────────────────────

  # Use realistic memory amounts: 8, 16, 32, 64
  mem         = cfg.memory or 16;
  memUnit     = cfg.memoryUnit or "G";
  timezone    = cfg.timezone or "Europe/London";

  # hugepages: accepts bool (true = default page size) or attrset
  hpCfg       = cfg.hugepages or false;
  hpEnabled   = if builtins.isAttrs hpCfg then hpCfg.enable or false else hpCfg;
  hpSize      = if builtins.isAttrs hpCfg then hpCfg.size or null else null;
  hpUnit      = if builtins.isAttrs hpCfg then hpCfg.unit or "G" else "G";

  cpu         = cfg.cpu or {};
  cores       = cpu.cores or 1;
  threads     = cpu.threads or 1;
  sockets     = cpu.sockets or 1;
  dies        = cpu.dies or 1;
  clusters    = cpu.clusters or 1;
  pinTo       = cpu.pinTo or [];
  hostCores   = cpu.hostCores or "";
  featReq     = (cpu.features or {}).require or [];
  featDis     = (cpu.features or {}).disable or [];
  vcpuCount   = builtins.length pinTo;
  hasPinning  = pinTo != [];

  fw          = cfg.firmware or {};
  secureBoot  = fw.secureBoot or true;

  hard        = cfg.hardening or {};
  hardened    = hard.enable or false;
  # kvm-pv-enforce-cpuid can cause guest crashes if the OS or drivers
  # attempt to use paravirtual MSRs that are no longer advertised.
  # Off by default — enable once you've confirmed the guest is stable.
  enforcePvCpuid = hard.enforcePvCpuid or false;
  emulator    = if hardened && hard ? emulator
                then hard.emulator
                else cfg.emulator or /run/libvirt/nix-emulators/qemu-system-x86_64;

  disks       = cfg.disks or [];
  cdroms      = cfg.cdroms or [];

  gpuCfg      = cfg.gpu or {};
  gpuAddrs    = gpuCfg.addresses or [];
  gpuStartBus = gpuCfg.startBus or 4;
  hasGpu      = gpuAddrs != [];

  # Looking Glass shared memory sizes (KVMFR module):
  #   Resolution        SDR    HDR
  #   1080p             32M    64M
  #   1200p             32M    64M
  #   1440p             64M    128M
  #   4K (2160p)        128M   256M
  # Ref: https://looking-glass.io/docs/B7/install/#ivshmem
  lg          = cfg.lookingGlass or {};
  lgEnabled   = lg.enable or false;
  lgSize      = lg.memSize or 67108864;

  net         = cfg.network or null;
  audioCfg    = cfg.audio or null;
  tpmEnabled  = cfg.tpm or false;
  spiceEnabled = cfg.spice or false;

  # evdev: list of input devices for direct host passthrough
  # Each entry: { dev = "/dev/input/eventN"; } or with grab options:
  #   { dev = "/dev/input/eventN"; grab = "all"; grabToggle = "ctrl-ctrl"; repeat = true; }
  # Lower latency than USB passthrough — ideal for Looking Glass setups.
  # Only needed when Looking Glass Host (LGH) is NOT installed on the guest.
  evdevInputs = cfg.evdev or [];

  extraDevices   = cfg.extraDevices or {};
  extraQemuArgs  = cfg.extraQemuArgs or [];

  # ── Memory backing ────────────────────────────────────────
  # Hugepages reduce TLB misses significantly for gaming VMs.
  # When hpSize is null, libvirt uses the host's default page size
  # (usually 2MB). For 1GB pages, set size = 1 and add the
  # corresponding boot.kernelParams on the host.

  memoryBackingSection = optionalAttrs hpEnabled {
    memoryBacking = {
      hugepages = if hpSize != null
        then { page = { size = hpSize; unit = hpUnit; }; }
        else {};
      nosharepages = {};  # Prevent KSM merging (security)
      locked = {};        # Prevent host from swapping VM memory
    };
  };

  # ── CPU pinning ──────────────────────────────────────────
  # pinTo maps vCPUs to host cores in order:
  #   pinTo = [ 2 10 3 11 ] → vCPU0→core2, vCPU1→core10, ...
  # hostCores are reserved for emulator + iothread overhead.

  pinningSection = optionalAttrs hasPinning {
    vcpu = { placement = "static"; count = vcpuCount; };
    cputune = {
      emulatorpin.cpuset = hostCores;
      iothreadpin = { iothread = 1; cpuset = hostCores; };
      vcpupin = indexed (i: core: {
        vcpu = i;
        cpuset = toString core;
      }) pinTo;
    };
  };

  # ── OS / firmware ─────────────────────────────────────────
  # Ref: https://libvirt.org/formatdomain.html#operating-system-booting
  # Note: domain UUID is NOT the guest SMBIOS UUID — spoof SMBIOS
  #       separately via qemu:commandline -smbios type=1,uuid=...

  osSection = {
    type = "hvm";
    arch = "x86_64";
    machine = "q35";
    bootmenu.enable = true;
  } // optionalAttrs (fw ? code) {
    loader = {
      readonly = true;
      secure = secureBoot;
      type = "pflash";
      path = fw.code;
    };
  } // optionalAttrs (fw ? varsPath) {
    nvram = {
      template = fw.varsTemplate;
      path = fw.varsPath;
    };
  };

  # ── CPU topology + features ──────────────────────────────
  # Ref: https://libvirt.org/formatdomain.html#cpu-model-and-topology

  cpuSection = {
    mode = "host-passthrough";
    check = "none";
    migratable = false;
    topology = { inherit sockets dies clusters cores threads; };
    cache.mode = "passthrough";
    maxphysaddr.mode = "passthrough";
    feature =
      # Performance features (e.g. svm/vmx, topoext, invtsc)
      (map (n: { policy = "require"; name = n; }) featReq) ++
      # Concealment features (e.g. hypervisor, ssbd, virt-ssbd)
      (map (n: { policy = "disable"; name = n; }) featDis);
  };

  # ── Clock ─────────────────────────────────────────────────
  # Ref: https://libvirt.org/formatdomain.html#time-keeping
  #
  # Hardened: use native TSC, disable all paravirtual clocks.
  #   - kvmclock: CONCEALMENT — KVM paravirtual clock exposes hypervisor
  #   - hypervclock: CONCEALMENT — Hyper-V clock exposes hypervisor
  #   - hpet: kept for timing compatibility
  #   - rtc/pit: disabled to reduce timer overhead
  #
  # Default: standard Windows timers with Hyper-V enlightenments.

  clockSection = if hardened then {
    offset = "localtime";
    timer = [
      { name = "tsc"; present = true; mode = "native"; tickpolicy = "discard"; }
      { name = "hpet"; present = true; }
      { name = "rtc"; present = false; }
      { name = "pit"; present = false; }
      { name = "kvmclock"; present = false; }
      { name = "hypervclock"; present = false; }
    ];
  } else {
    offset = "localtime";
    timer = [
      { name = "rtc"; tickpolicy = "catchup"; }
      { name = "pit"; tickpolicy = "delay"; }
      { name = "hpet"; present = false; }
      { name = "hypervclock"; present = true; }
    ];
  };

  # ── Features ──────────────────────────────────────────────
  # Ref: https://libvirt.org/formatdomain.html#hypervisor-features
  #
  # Hardened: disable ALL Hyper-V enlightenments — enlightenments on
  # "bare-metal" are flagged as extremely suspicious by anti-cheats.
  #
  # vendor_id: when KVM is NOT patched, set state=on with a 12-char
  #   string to fix NVIDIA Code 43 error. When KVM IS patched, use
  #   state=off instead. The value does NOT need to match the CPU
  #   vendor — it's the hypervisor vendor string (CPUID 0x40000000).
  #
  # kvm.hidden:   CONCEALMENT — hides KVM from CPUID-based MSR discovery
  # pmu:          CONCEALMENT — disables Performance Monitoring Unit
  # vmport:       CONCEALMENT — disables VMware I/O backdoor (port 0x5658)
  # msrs.unknown: CONCEALMENT — injects #GP(0) on RDMSR/WRMSR to
  #               unhandled MSRs (prevents fingerprinting via MSR probing)
  # smm:          required for UEFI Secure Boot (OVMF SMM_REQUIRE)
  # ps2:          disabled to remove virtual PS/2 controller

  featuresSection = if hardened then {
    acpi = {}; apic = {};
    hyperv = {
      mode = "custom";
      relaxed.state = false;
      vapic.state = false;
      spinlocks.state = false;
      vpindex.state = false;
      runtime.state = false;
      synic.state = false;
      stimer.state = false;
      reset.state = false;
      frequencies.state = false;
      vendor_id = {
        state = true;
        value = hard.vendorId or "pK4m7TqXw9bR";
      };
      reenlightenment.state = false;
      tlbflush.state = false;
      ipi.state = false;
      evmcs.state = false;
      avic.state = false;
      emsr_bitmap.state = false;
      xmm_input.state = false;
    };
    kvm.hidden.state = true;
    smm.state = secureBoot;
    pmu.state = false;
    ioapic.driver = "kvm";
    msrs.unknown = "fault";
    vmport.state = false;
    ps2.state = false;
  } else {
    acpi = {}; apic = {};
    hyperv = {
      mode = "custom";
      relaxed.state = true;
      vapic.state = true;
      spinlocks = { state = true; retries = 8191; };
      vpindex.state = true;
      runtime.state = true;
      synic.state = true;
      stimer.state = true;
      reset.state = true;
      frequencies.state = true;
    };
    vmport.state = false;
  };

  # ── Device builders ───────────────────────────────────────
  # Ref: https://libvirt.org/formatdomain.html#hard-drives-floppy-disks-cdroms
  #
  # Disk bus options for anti-detection:
  #   "sata"  — safest, no virtio fingerprint
  #   "nvme"  — more realistic for modern systems
  #   "virtio" — best performance, but detectable
  #
  # io options: "io_uring" (modern, best async), "native" (libaio),
  #             "threads" (for block devices)

  mkDisk = idx: d: {
    type = "file";
    device = "disk";
    driver = {
      name = "qemu";
      type = d.format or "qcow2";
      cache = d.cache or "none";
      io = d.io or "io_uring";
      discard = d.discard or "unmap";
    };
    source.file = d.file;
    target = {
      dev = d.dev or "sd${builtins.elemAt letters idx}";
      bus = d.bus or "sata";
    };
  } // optionalAttrs (d ? serial) { inherit (d) serial; }
    // optionalAttrs (d ? boot)   { boot.order = d.boot; }
    // optionalAttrs (idx == 0)   {
      address = {
        type = "drive"; controller = 0;
        bus = 0; target = 0; unit = 0;
      };
    };

  cdromOffset = builtins.length disks + 1;

  mkCdrom = idx: c: {
    type = "file";
    device = "cdrom";
    readonly = {};
    driver = { name = "qemu"; type = "raw"; };
    source.file = c.file;
    target = {
      dev = c.dev or "sd${builtins.elemAt letters (idx + cdromOffset)}";
      bus = "sata";
    };
  };

  mkHostdev = idx: addr: {
    mode = "subsystem";
    type = "pci";
    managed = true;
    source.address = {
      domain = 0;
      inherit (addr) bus slot function;
    };
    address = {
      type = "pci"; domain = 0;
      bus = gpuStartBus + idx;
      slot = 0; function = 0;
    };
    alias.name = "hostdev${toString idx}";
  };

  # ── Devices (assembled) ───────────────────────────────────

  mkEvdev = e:
    let hasGrab = e ? grab || e ? grabToggle || e ? repeat;
    in {
      type = "evdev";
      source = if hasGrab then {
        inherit (e) dev;
      } // optionalAttrs (e ? grab) { inherit (e) grab; }
        // optionalAttrs (e ? grabToggle) { inherit (e) grabToggle; }
        // optionalAttrs (e ? repeat) { inherit (e) repeat; }
      else { inherit (e) dev; };
    };

  devicesSection = {
    inherit emulator;

    disk = (indexed mkDisk disks) ++ (indexed mkCdrom cdroms);

    input = [
      { type = "keyboard"; bus = "usb"; }
      { type = "mouse"; bus = "usb"; }
    ] ++ (map mkEvdev evdevInputs);

    controller = [
      { type = "usb"; index = 0; model = "qemu-xhci"; }
      { type = "pci"; index = 0; model = "pcie-root"; }
      { type = "pci"; index = 1; model = "pcie-root-port"; }
      { type = "pci"; index = 16; model = "pcie-to-pci-bridge"; }
      { type = "sata"; index = 0;
        address = { type = "pci"; domain = 0; bus = 0; slot = 31; function = 2; }; }
      { type = "virtio-serial"; index = 0;
        address = { type = "pci"; domain = 0; bus = 3; slot = 0; function = 0; }; }
    ];

    # CONCEALMENT: no virtual video device — prevents hypervisor detection
    # via virtualised GPU vendor IDs. Required for Looking Glass.
    video.model.type = "none";

    watchdog = { model = "itco"; action = "reset"; };

    # CONCEALMENT: disable virtio balloon — no dynamic RAM / no virtio fingerprint
    memballoon.model = "none";

  } // optionalAttrs (net != null) {
    # DO NOT use virtio for anti-detection — use e1000e or bridge
    interface = [({
      type = net.type or "bridge";
      mac.address = net.mac;  # Always randomise MAC address
      source.bridge = net.bridge;
      model.type = net.model or "e1000e";
      link.state = "up";
    } // optionalAttrs (net ? pciBus) {
      address = { type = "pci"; domain = 0; bus = net.pciBus; slot = 0; function = 0; };
    })];
  } // optionalAttrs tpmEnabled {
    # TPM emulation requires swtpm on the host
    tpm = {
      model = "tpm-crb";
      backend = { type = "emulator"; version = "2.0"; };
    };
  } // optionalAttrs (audioCfg != null) {
    sound = {
      model = "ich9";
      codec.type = "micro";
      audio.id = 1;
      address = { type = "pci"; domain = 0; bus = 0; slot = 27; function = 0; };
    };
    audio = {
      id = 1;
      type = audioCfg.backend or "pipewire";
      runtimeDir = "/run/user/${toString (audioCfg.uid or 1000)}";
      input.mixingEngine = false;
      output.mixingEngine = false;
    };
  } // optionalAttrs spiceEnabled {
    redirdev = [
      { bus = "usb"; type = "spicevmc"; }
      { bus = "usb"; type = "spicevmc"; }
    ];
    graphics = {
      type = "spice"; port = "-1"; tlsPort = "-1";
      autoport = true; listen.type = "address";
    };
  } // optionalAttrs hasGpu {
    hostdev = indexed mkHostdev gpuAddrs;
  } // extraDevices;

  # ── QEMU command line args ────────────────────────────────
  # Ref: https://www.qemu.org/docs/master/system/qemu-manpage.html
  #
  # kvm-pv-enforce-cpuid: By default KVM allows the guest to use ALL
  #   paravirtual MSRs (0x4b564d00–0x4b564d08) even when kvm=off hides
  #   the CPUID leaves. This flag enforces CPUID: if a PV feature bit
  #   is absent, RDMSR/WRMSR to that MSR will inject #GP into the guest.
  #   Without this, anti-cheats can detect KVM via MSR probing even when
  #   the CPUID signature is hidden.
  #   Ref: https://docs.kernel.org/virt/kvm/x86/msr.html

  mkArg = v: { value = v; };

  # CONCEALMENT: enforce CPUID-gated PV MSR access (opt-in, can cause crashes)
  kvmEnforceArgs = optionals (hardened && enforcePvCpuid) [
    (mkArg "-cpu")
    (mkArg "host,kvm-pv-enforce-cpuid=on")
  ];

  # Spoof SMBIOS (entire binary dump from host hardware)
  # Ref: https://www.dmtf.org/sites/default/files/standards/documents/DSP0134_3.9.0.pdf
  smbiosArgs = optionals (hardened && hard ? smbios) [
    (mkArg "-smbios")
    (mkArg "file=${hard.smbios}")
  ];

  # Spoof ACPI tables (e.g. spoofed_devices.aml, battery SSDT)
  acpiArgs =
    optionals (hardened && hard ? acpiTable) [
      (mkArg "-acpitable")
      (mkArg "file=${hard.acpiTable}")
    ] ++
    optionals (hardened && hard ? acpiBattery) [
      (mkArg "-acpitable")
      (mkArg "file=${hard.acpiBattery}")
    ];

  # IVSHMEM for Looking Glass (KVMFR kernel module)
  # The kernel module provides DMA GPU transfers via shared memory.
  # Ref: https://looking-glass.io/docs/B7/install/#ivshmem
  lgArgs = optionals lgEnabled [
    (mkArg "-device")
    (mkArg ''{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'')
    (mkArg "-object")
    (mkArg ''{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":${toString lgSize},"share":true}'')
  ];

  allQemuArgs = kvmEnforceArgs ++ smbiosArgs ++ acpiArgs
                ++ lgArgs ++ (map mkArg extraQemuArgs);

  qemuCmdlineSection = optionalAttrs (allQemuArgs != []) {
    qemu-commandline.arg = allQemuArgs;
  };

  # ── QEMU overrides (SSD spoofing for anti-detection) ────
  # Ref: https://libvirt.org/drvqemu.html#overriding-properties-of-qemu-devices
  #
  # Only needed for SSD-backed virtual storage (.qcow2).
  # rotation_rate=1: tells guest this is an SSD (non-rotational)
  # discard_granularity=512: realistic value for a real SSD
  #   (0 is suspicious — real SSDs always report non-zero)

  qemuOverrideSection = optionalAttrs hardened {
    qemu-override.device = {
      alias = "sata0-0-0";
      frontend.property = [
        { name = "rotation_rate"; type = "unsigned"; value = "1"; }
        { name = "discard_granularity"; type = "unsigned"; value = "512"; }
      ];
    };
  };

  # ── Misc (lifecycle, power management) ───────────────────
  # Ref: https://libvirt.org/formatdomain.html#power-management
  #
  # CONCEALMENT: S3/S4 sleep states — real hardware supports these;
  # their absence can be a detection vector.

  miscSection = {
    on_poweroff = "destroy";
    on_reboot = "restart";
    on_crash = "destroy";
    pm = {
      suspend-to-mem.enabled = true;   # S3 (suspend-to-RAM)
      suspend-to-disk.enabled = true;  # S4 (hibernate)
    };
  };

in

# ── Final assembly ───────────────────────────────────────
{
  type = "kvm";
  inherit (cfg) name uuid;

  memory = mkUnit memUnit mem;
  currentMemory = mkUnit memUnit mem;
  iothreads.count = 1;

  os = osSection;
  features = featuresSection;
  cpu = cpuSection;
  clock = clockSection;
  devices = devicesSection;
}
// memoryBackingSection
// pinningSection
// qemuCmdlineSection
// qemuOverrideSection
// miscSection
// (cfg.extraAttrs or {})
