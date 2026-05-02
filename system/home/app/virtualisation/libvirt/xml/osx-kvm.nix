# OSX-KVM macOS VM — libvirt domain definition.
#
# Doesn't go through ./mkVM.nix because that's a hardened/anti-detection
# builder for Windows guests (Hyper-V enlightenments off, kvm.hidden,
# msrs.unknown=fault, no virtual GPU, etc.) — none of which fit a macOS
# guest. Defined raw, kept short.
#
# The non-obvious bit: pkgs.qemu_kvm, NOT the system default emulator.
# /run/libvirt/nix-emulators/qemu-system-x86_64 points at barely-metal-qemu
# (the patched build for Windows anti-detection); its PCI/LPC patches hang
# OSX-KVM's macOS-OVMF in DXE init. Stock qemu_kvm boots fine. See git log
# of this file (~May 2026) for the full bisection if you ever need it.

{ pkgs, ... }:

let
  repoPath = "/home/stefan/Documents/OSX-KVM";
in
{
  type = "kvm";
  name = "osx-kvm";
  uuid = "9a8f7c3e-2d4b-4a1c-9e6f-5b0c1d2e3f4a";

  memory        = { unit = "MiB"; count = 4096; };
  currentMemory = { unit = "MiB"; count = 4096; };

  vcpu = { placement = "static"; count = 4; };

  os = {
    type    = "hvm";
    arch    = "x86_64";
    machine = "q35";
    # OSX-KVM ships its own macOS-patched OVMF. Both pflash files MUST live
    # outside /nix/store — libvirt's firmware-descriptor matcher otherwise
    # silently rewrites <loader> to nixpkgs stock OVMF, which lacks the
    # macOS patches and won't boot.
    loader = {
      readonly = true;
      type     = "pflash";
      path     = "${repoPath}/OVMF_CODE_4M.fd";
    };
    nvram = {
      # 4M-format VARS (paired by size with OVMF_CODE_4M). The 128 KB
      # legacy VARS that OSX-KVM ships work with shell-style -drive pflash
      # but break libvirt's -blockdev pflash binding.
      template = "${repoPath}/OVMF_VARS_4M.fd";
      path     = "/var/lib/libvirt/qemu/nvram/osx-kvm_VARS.fd";
    };
  };

  features = {
    acpi   = { };
    apic   = { };
    vmport = { state = false; };
  };

  cpu = {
    mode  = "custom";
    match = "exact";
    check = "none";
    model = { fallback = "allow"; name = "Skylake-Client"; };
    topology = { sockets = 1; cores = 2; threads = 2; };
  };

  clock = {
    offset = "utc";
    timer = [
      { name = "hpet"; present = false; }
      { name = "tsc";  present = true; mode = "native"; }
    ];
  };

  on_poweroff = "destroy";
  on_reboot   = "restart";
  on_crash    = "destroy";

  devices = {
    emulator = "${pkgs.qemu_kvm}/bin/qemu-system-x86_64";

    disk = [
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "qcow2";
        source.file = "${repoPath}/OpenCore/OpenCore.qcow2";
        target = { dev = "sda"; bus = "sata"; };
        boot.order = 1;
      }
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "raw";
        source.file = "${repoPath}/BaseSystem.img";
        target = { dev = "sdb"; bus = "sata"; };
      }
      {
        type = "file"; device = "disk";
        driver.name = "qemu"; driver.type = "qcow2";
        source.file = "${repoPath}/mac_hdd_ng.img";
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
    ];

    interface = [{
      # User-mode networking (slirp NAT) + virtio-net-pci, matching OSX-KVM's
      # working shell script. macOS recovery (BaseSystem) doesn't ship e1000e
      # drivers, but OSX-KVM's OpenCore.qcow2 includes the kexts needed for
      # virtio-net-pci. User-mode also avoids needing a bridge on the host
      # (bridges block guest internet unless DHCP/NAT is set up explicitly).
      # Internet is required to install macOS — recovery downloads the actual
      # OS image from Apple over this link.
      #
      # MAC matches the shell script's value so the install picks up the same
      # network identity.
      type        = "user";
      mac.address = "52:54:00:c9:18:27";
      model.type  = "virtio";
      link.state  = "up";
      # bus=0 (pcie.0) avoids libvirt auto-generating a chain of
      # pcie-root-ports to make a higher bus number exist.
      address = { type = "pci"; domain = 0; bus = 0; slot = 6; function = 0; };
    }];

    input = [
      { type = "keyboard"; bus = "usb"; }
      { type = "tablet";   bus = "usb"; }
    ];

    sound      = { model = "ich9"; audio.id = 1; };
    audio      = { id = 1; type = "pipewire"; runtimeDir = "/run/user/1000"; };
    video.model.type = "vmvga";
    memballoon.model = "none";

    graphics = {
      type = "spice"; autoport = true;
      listen = { type = "address"; address = "127.0.0.1"; };
    };
  };

  qemu-commandline.arg = [
    # Apple SMC emulation — OSX-KVM's OpenCore.qcow2 expects QEMU's
    # isa-applesmc rather than VirtualSMC.kext.
    { value = "-device"; }
    { value = "isa-applesmc,osk=ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"; }
    { value = "-smbios"; }
    { value = "type=2"; }
    # Override libvirt's -cpu Skylake-Client,mpx=off (last -cpu wins).
    # +invtsc and vmware-cpuid-freq=on are macOS-required quirks libvirt's
    # <cpu> can't express.
    { value = "-cpu"; }
    { value = "Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on"; }
  ];
}
