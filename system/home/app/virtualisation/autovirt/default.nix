# configuration.nix
{
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    inputs.barely-metal.nixosModules.default
    inputs.nixos-facter-modules.nixosModules.facter
  ];

  # Point nixos-facter at your hardware report
  facter.reportPath = ./facter.json;

  barelyMetal = {
    enable = true;

    # Pass your hardware probe data
    probeData = builtins.fromJSON (builtins.readFile ./probe.json);

    # Users to add to kvm, libvirtd, input groups
    users = [ "stefan" ];

    # Replace the OVMF boot logo (saved by barely-metal-probe)
    spoofing.bootLogo = ./boot-logo.bmp;

    # Looking Glass shared memory display (optional)
    lookingGlass = {
      enable = true;
      user = "stefan";
      group = "kvm";
      shmSize = 32;
      spoofKvmfrIds = false;
    };
  };

  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "kvmfr-permissions";
      text = ''
        SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660"
      '';
      destination = "/etc/udev/rules.d/70-kvmfr.rules";
    }
  );

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
