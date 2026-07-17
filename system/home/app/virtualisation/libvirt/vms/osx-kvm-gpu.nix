args@{ pkgs, osxKvm, ... }:

let
  # ── OpenCore source override (DarwinOCPkg) ─────────────────────────────────
  # Switch this VM's OpenCore image to royalgraphx/DarwinOCPkg (OpenCorePkg 1.0.4 repackaged with curated HFS+/partition drivers) via overrideScope, shadowing the function-arg osxKvm.
  osxKvm = args.osxKvm.overrideScope (final: prev: {
    opencore = prev.opencore.override { source = "darwinOCPkg"; };
  });

  # ── OpenCore / config.plist ──
  # mkMacOSVM/mkImage expect `drivers` as a sibling arg, so pull it back out of the profile for a plain `inherit`.
  inherit (profile) drivers;

  # --- ACPI table sources --------------------------------------------------

  ssdtEcUsbx = pkgs.fetchurl {
    url = "https://github.com/royalgraphx/DarwinOCPkg/raw/refs/heads/main/Docs/AcpiSamples/SSDT-EC-USBX.aml";
    sha256 = "1a5lywmg7i64ygy3d6hsliyg1hbd53akm88sva8faqidhhv9xh21";
  };
  ssdtPlug = pkgs.fetchurl {
    url = "https://github.com/royalgraphx/DarwinOCPkg/raw/refs/heads/main/Docs/AcpiSamples/SSDT-PLUG.aml";
    sha256 = "1703gw6hkwbb4ll8cj9dcbvxlpn5x11qhfxcgsdgljfb51lkb96z";
  };

  # --- Kext sources --------------------------------------------------------

  vmHideSrc = pkgs.fetchzip {
    url = "https://github.com/Carnations-Botanica/VMHide/releases/download/2.0.0/VMHide-2.0.0-RELEASE.zip";
    sha256 = "199qmmkpcgswdb9pdvw55n2kvzvhprzq0qj78i0sn40yvy631ppz";
    stripRoot = false;
  };
  vmHide = pkgs.runCommand "VMHide-2.0.0" { } ''
    cp -r ${vmHideSrc}/VMHide.kext $out
  '';

  # --- OpenCore profile ----------------------------------------------------

  profile = {
    smbios = {
      productName = "MacPro7,1";
      serial = "F5KHLBZ1P7QM";
      mlb = "F5K216700CDK3F7JA";
      uuid = "2271E506-8817-4932-9AE5-9C6EBF678EAB";
      romMac = "E0:ED:8C:79:5B:E0";
    };

    bootArgs = "keepsyms=1 agdpmod=pikera npci=0x3000";

    kexts = with osxKvm.kexts; [
      {
        name = "Lilu.kext";
        bundle = Lilu;
        bundlePath = "Lilu.kext";
        executablePath = "Contents/MacOS/Lilu";
      }
      {
        name = "VirtualSMC.kext";
        bundle = VirtualSMC;
        bundlePath = "VirtualSMC.kext";
        executablePath = "Contents/MacOS/VirtualSMC";
      }
      {
        name = "WhateverGreen.kext";
        bundle = WhateverGreen;
        bundlePath = "WhateverGreen.kext";
        executablePath = "Contents/MacOS/WhateverGreen";
        minKernel = "10.0.0";
      }
      {
        name = "AppleALC.kext";
        bundle = AppleALC;
        bundlePath = "AppleALC.kext";
        executablePath = "Contents/MacOS/AppleALC";
      }
      {
        name = "AppleMCEReporterDisabler.kext";
        bundle = appleMCEReporterDisabler;
        bundlePath = "AppleMCEReporterDisabler.kext";
        comment = "Disable MCE reporter on non-ECC guest RAM (MP7,1 board-id)";
        minKernel = "21.0.0";
      }
      {
        name = "CryptexFixup.kext";
        bundle = CryptexFixup;
        bundlePath = "CryptexFixup.kext";
        executablePath = "Contents/MacOS/CryptexFixup";
        comment = "Boot Ventura+ under MacPro7,1 SMBIOS";
        minKernel = "22.0.0";
      }
      {
        name = "VMHide.kext";
        bundle = vmHide;
        bundlePath = "VMHide.kext";
        executablePath = "Contents/MacOS/VMHide";
        minKernel = "19.0.0";
        comment = "Mask hypervisor CPUID/SMBIOS/ioreg from anti-VM heuristics";
      }
    ];

    kextBlocks = [
      {
        identifier = "com.apple.driver.AppleTyMCEDriver";
        enabled = true;
        comment = "Block AppleTyMCEDriver - panics on MP7,1 without Xeon thermal sensors";
      }
    ];

    acpi = [
      {
        name = "SSDT-EC-USBX.aml";
        source = ssdtEcUsbx;
        comment = "Fake USB-only EC + USBX power properties";
      }
      {
        name = "SSDT-PLUG.aml";
        source = ssdtPlug;
        comment = "X86PlatformPlugin (XCPM) CPU power management";
      }
    ];

    drivers = [
      "OpenRuntime.efi"
      "OpenPartitionDxe.efi"
      "HfsPlus.efi"
      "ResetNvramEntry.efi"
    ];
  };

  # --- config.plist deep-merge overrides -----------------------------------

  plistOverrides = {
    Booter.Quirks = {
      EnableWriteUnprotector = false;
      RebuildAppleMemoryMap = true;
      SetupVirtualMap = false;
      SyncRuntimePermissions = true;
    };

    Kernel = {
      Patch = [
        {
          Arch = "x86_64";
          Base = "__ZN17IOPCIConfigurator18IOPCIIsHotplugPortEP16IOPCIConfigEntry";
          Comment = "CaseySJ | IOPCIIsHotplugPort | Fix PCI bus enumeration on KVM | 13.0+";
          Count = 1;
          Enabled = true;
          Find = {
            _type = "data";
            value = "RYQAdUs=";
          };
          Identifier = "com.apple.iokit.IOPCIFamily";
          Limit = 0;
          Mask = {
            _type = "data";
            value = "//8A//8=";
          };
          MaxKernel = "25.99.99";
          MinKernel = "22.0.0";
          Replace = {
            _type = "data";
            value = "AAAA6wA=";
          };
          ReplaceMask = {
            _type = "data";
            value = "AAAA/wA=";
          };
          Skip = 0;
        }
      ];
      Quirks = {
        ForceSecureBootScheme = true; # x86 SB matches Apple's verifier
        PanicNoKextDump = true; # reduce panic-log noise
        PowerTimeoutKernelPanic = true; # Catalina+ power-state panic fix
        ProvideCurrentCpuInfo = true; # avoid hypervisor-mismatch panic
      };
      Emulate.MaxKernel = "29.99.99";
      Scheme = {
        CustomKernel = false;
        FuzzyMatch = false;
        KernelArch = "x86_64";
        KernelCache = "Auto";
      };
    };

    Misc = {
      Boot.PollAppleHotKeys = true;
      Debug = {
        AppleDebug = true;
        ApplePanic = true;
        DisableWatchDog = true;
        Target = 51;
      };
      Security = {
        AllowSetDefault = true;
        ExposeSensitiveData = 15;
        ScanPolicy = 0;
        Vault = "Optional";
      };
    };

    UEFI.APFS = {
      MinDate = -1;
      MinVersion = -1;
    };
  };

  # 12 vCPUs pinned onto the same cores as the Windows VMs, hoisted to a top-level attr so domains.nix's qemu hook can read `m.pin` for governor switching.
  pin = import ../lib/pinning.nix;

  vm = (import ../lib/mkMacOSVM.nix { inherit pkgs osxKvm; }) {
    inherit profile plistOverrides drivers;
    name = "osx-kvm-gpu";
    uuid = "9a8f7c3e-2d4b-4a1c-9e6f-5b0c1d2e3f4b";
    # Reshape the domain to DarwinKVM's reference XML (see darwinKvmStyle in mkMacOSVM.nix); CPU model and <loader>/<nvram> stay OSX-KVM.
    darwinKvmStyle = true;
    memory = 16384;
    topology = {
      sockets = 1;
      cores = 6;
      threads = 2;
    };
    inherit pin;
    hostdevs = [
      {
        bus = 3;
        slot = 0;
        function = 0;
        rom = "/var/lib/libvirt/vbios/6950xt.rom";
      }
      {
        bus = 3;
        slot = 0;
        function = 1;
      }
    ];
    spoofGpu = {
      aliasIdx = 0;
      deviceId = 29631;
    };
    videos = [ { model.type = "none"; } ];
    portForwards = [
      {
        proto = "tcp";
        from = 47984;
      } # Sunshine HTTPS (pairing)
      {
        proto = "tcp";
        from = 47989;
        to = 47990;
      } # Sunshine HTTP UI + redirect
      {
        proto = "tcp";
        from = 48010;
      } # Sunshine RTSP
      {
        proto = "udp";
        from = 47998;
        to = 48000;
      } # Sunshine video / control / audio
      {
        proto = "tcp";
        from = 1714;
        to = 1715;
      } # KDE Connect data (low half)
      {
        proto = "tcp";
        from = 1717;
        to = 1764;
      } # KDE Connect data (high half; skip 1716)
    ];
  };
in
{
  inherit (vm) domain configPlist;
  inherit pin;

  governor = {
    enable = true;
    active = "performance";
    restore = "schedutil";
  };
}
