# Declarative libvirt domain builder for Windows guests, with hardened (anti-detection) and default profiles; macOS uses ./mkMacOSVM.nix.

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
  # kvm-pv-enforce-cpuid can crash the guest on unadvertised PV MSRs, so it stays off until the guest is confirmed stable.
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

  # USB passthrough by integer vendor:product (libvirt reads base-0); the device must be present at VM start since nixvirt's hostdev has no startupPolicy.
  usbCfg      = cfg.usb or {};
  usbDevices  = usbCfg.devices or [];
  hasUsb      = usbDevices != [];

  # Looking Glass KVMFR shmem: 32M for 1080p/1200p, 64M for 1440p, 128M for 4K (double each for HDR).
  lg          = cfg.lookingGlass or {};
  lgEnabled   = lg.enable or false;
  lgSize      = lg.memSize or 67108864;

  net         = cfg.network or null;
  audioCfg    = cfg.audio or null;
  tpmEnabled  = cfg.tpm or false;
  spiceEnabled = cfg.spice or false;

  # evdev input devices passed straight through to the host for lower latency than USB.
  evdevInputs = cfg.evdev or [];

  extraDevices   = cfg.extraDevices or {};
  extraQemuArgs  = cfg.extraQemuArgs or [];

  # ── Memory backing ────────────────────────────────────────
  # Hugepages cut TLB misses; null hpSize uses the host default (2MB), while 1GB pages need size = 1 plus host boot.kernelParams.

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
  # pinTo maps vCPUs to host cores in order; hostCores are reserved for emulator + iothread overhead.

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
  # Domain UUID is NOT the guest SMBIOS UUID — spoof SMBIOS separately via qemu:commandline -smbios type=1,uuid=...

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
  # Hardened uses native TSC with paravirtual clocks off (kvmclock/hypervclock leak the hypervisor); default uses standard Windows timers with Hyper-V enlightenments.

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
  # Hardened disables all Hyper-V enlightenments and hides KVM/PMU/vmport/PS2 to dodge anti-cheat fingerprinting, while vendor_id state=on fixes NVIDIA Code 43 on unpatched KVM.

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
    smm.state = secureBoot;
  };

  # ── Device builders ───────────────────────────────────────
  # Disk bus for anti-detection: sata (safest, no virtio fingerprint), nvme (realistic), or virtio (fastest but detectable).

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

  # USB hostdev lands on the emulated xHCI bus; managed=true detaches it from the host driver on start and reattaches on stop.
  mkUsbHostdev = u: {
    mode = "subsystem";
    type = "usb";
    managed = u.managed or true;
    source = {
      vendor.id = u.vendor;
      product.id = u.product;
    };
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

    # No virtual video device — avoids virtualised-GPU vendor IDs and is required for Looking Glass.
    video.model.type = "none";

    watchdog = { model = "itco"; action = "reset"; };

    # No virtio balloon — no dynamic RAM and no virtio fingerprint.
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
  } // optionalAttrs (hasGpu || hasUsb) {
    hostdev = (optionals hasGpu (indexed mkHostdev gpuAddrs))
              ++ (optionals hasUsb (map mkUsbHostdev usbDevices));
  } // extraDevices;

  # ── QEMU command line args ────────────────────────────────
  # kvm-pv-enforce-cpuid makes probing an absent PV MSR inject #GP even when kvm=off, closing an MSR-based KVM detection vector.

  mkArg = v: { value = v; };

  # Enforce CPUID-gated PV MSR access (opt-in, can crash the guest).
  kvmEnforceArgs = optionals (hardened && enforcePvCpuid) [
    (mkArg "-cpu")
    (mkArg "host,kvm-pv-enforce-cpuid=on")
  ];

  # Spoof SMBIOS from a binary dump of the host hardware.
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

  # IVSHMEM for Looking Glass — the KVMFR kernel module provides DMA GPU transfers via shared memory.
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
  # SSD-backed qcow2 only: rotation_rate=1 marks it non-rotational and discard_granularity=512 is a realistic value.

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
  # S3/S4 sleep states are advertised because real hardware supports them and their absence is a detection vector.

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
