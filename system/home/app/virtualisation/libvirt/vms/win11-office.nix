# Plain Office VM: no hardening, GPU passthrough, pinning, hugepages or governor. inputs/pkgs are
# unused but kept in the signature for consistency with the other VMs.

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
    # No pinTo / hostCores: let the host scheduler place vCPUs.
    features = {
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

  hardening.enable = false;

  disks = [{
    file = /var/lib/libvirt/images/win11-office.qcow2;
    format = "qcow2";
    serial = "OFFICE00000000000001";
    boot = 1;
  }];

  # Attach a Windows ISO here on first install.
  cdroms = [ ];

  # mkWindowsVM forces video.model.type = "none"; extraDevices merges last, restoring a display.
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

  tpm = true; # Windows 11 requirement
  spice = true;

  governor.enable = false;

  # mkWindowsVM only emits <vcpu count> when pinning, but <topology> always declares cores×threads,
  # so state the total (4×2) or libvirt rejects the mismatch.
  extraAttrs = {
    vcpu = { placement = "static"; count = 8; };
  };
}
