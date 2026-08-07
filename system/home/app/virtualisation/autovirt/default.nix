{
  pkgs,
  inputs,
  lib,
  ...
}:

let
  hw = import ../../../../../hosts/home/hardware-profile.nix;
in
{
  imports = [
    inputs.barely-metal.nixosModules.default
    inputs.nixos-facter-modules.nixosModules.facter
  ];

  facter.reportPath = ./facter.json;
  # NM owns addressing here, so facter's per-NIC useDHCP only adds a 40-<name>.link per detected
  # interface. The one for the unused Realtek matched its kernel name and, having no NamePolicy,
  # pinned it as "eth0" instead of letting udev give it a predictable name.
  facter.detected.dhcp.interfaces = [ ];

  barelyMetal = {
    # On for firmware/SMBIOS/Secure-Boot activation, minus its two clobbering side effects: VMs keep
    # their own emulators (opted in per-VM via qemuPackage) and the custom libvirt networks survive.
    enable = true;
    setDefaultQemuPackage = false;
    network.randomizeMac = false;

    # autoDetectDrivers off so nvidia isn't blacklisted (dgpu-enable must still bind it);
    # amdVendorReset off because the passthrough card is NVIDIA.
    vfio = {
      enable = true;
      pciIds = hw.dgpu.deviceIds;
      autoDetectDrivers = false;
      amdVendorReset = false;
    };

    probeData = builtins.fromJSON (builtins.readFile ./probe.json);

    users = [ "stefan" ];

    # Saved by barely-metal-probe.
    spoofing.bootLogo = ./boot-logo.bmp;

    lookingGlass = {
      enable = true;
      user = "stefan";
      group = "kvm";
      shmSize = 128;
      spoofKvmfrIds = false;
    };
  };

  virtualisation.libvirtd.qemu.runAsRoot = true;
  virtualisation.libvirtd.qemu.verbatimConfig = lib.mkForce ''
    cgroup_device_acl = [
      "/dev/kvmfr0",
      "/dev/null",
      "/dev/kvm",
      "/dev/full",
      "/dev/zero",
      "/dev/random",
      "/dev/urandom",
      "/dev/ptmx",
      "/dev/kqemu",
      "/dev/rtc"
    ]
  '';
}
