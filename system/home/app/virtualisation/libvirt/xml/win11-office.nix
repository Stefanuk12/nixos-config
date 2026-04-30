# VM configuration — consumed by mkVM (domain XML) and mkQemuHook (CPU governor).
# This file is pure data; xml.nix handles the actual building.
#
# Plain Office workload VM:
#   - no hardening (no SMBIOS/ACPI/CPU concealment, stock qemu)
#   - no GPU passthrough (display via SPICE + virtual QXL)
#   - no CPU pinning / hugepages / governor switching
# inputs/pkgs are kept in the signature for consistency with other VM
# configs even though this file no longer uses them.

{ inputs, pkgs }:

{
  name = "win11-office";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f33";

  memory = 8;
  hugepages.enable = false;

  cpu = {
    cores = 4;
    threads = 2;
    clusters = 1;
    # No pinTo / hostCores — let the host scheduler place vCPUs.
    features = {
      # svm + topoext are still useful for correctness on AMD hosts.
      require = [ "svm" "topoext" ];
      disable = [ ];
    };
  };

  firmware = {
    code = "/var/lib/barely-metal/firmware/OVMF_CODE.fd";
    varsTemplate = "/var/lib/barely-metal/firmware/OVMF_VARS.fd";
    varsPath = /var/lib/libvirt/qemu/nvram/win11-office_VARS.fd;
    secureBoot = true;   # Windows 11 requirement
  };

  # Hardening fully disabled — mkVM will use the default nixpkgs qemu
  # emulator and skip SMBIOS / ACPI / MSR / clock concealment.
  hardening.enable = false;

  disks = [{
    file = /var/lib/libvirt/images/win11-office.qcow2;
    format = "qcow2";
    serial = "OFFICE00000000000001";
    boot = 1;
  }];

  # Attach a Windows ISO here on first install, e.g.
  # cdroms = [ { file = "/var/lib/libvirt/images/Win11_24H2_English_x64.iso"; } ];
  cdroms = [ ];

  # No GPU passthrough.
  # mkVM unconditionally sets `video.model.type = "none"` (needed for
  # Looking Glass / concealment), which would leave this VM headless.
  # Override via extraDevices — this is merged last in mkVM and replaces
  # the top-level `video` key, giving us a normal QXL + SPICE display.
  extraDevices = {
    video.model = {
      type = "qxl";
      ram = 65536;
      vram = 65536;
      vgamem = 16384;
      heads = 1;
      primary = true;
    };
  };

  lookingGlass.enable = false;

  network = {
    bridge = "br0";
    mac = "52:54:3a:20:c8:5f";
    model = "e1000e";
    pciBus = 10;
  };

  audio = {
    backend = "pipewire";
    uid = 1000;
  };

  tpm = true;      # Windows 11 requirement
  spice = true;    # primary display path

  # Governor switching left off — Office isn't perf-critical.
  governor.enable = false;

  # mkVM only emits <vcpu count=...> when CPU pinning is enabled,
  # but the <topology> still declares sockets*dies*clusters*cores*threads
  # vCPUs. Without pinning, libvirt defaults <vcpu> to 1 and rejects the
  # mismatch. Declare the total here so topology and vcpu count agree.
  # 1 socket × 1 die × 1 cluster × 4 cores × 2 threads = 8 vCPUs.
  extraAttrs = {
    vcpu = { placement = "static"; count = 8; };
  };
}
