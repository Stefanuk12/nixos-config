{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  security.sudo.extraRules = [
    {
      groups = [ "libvirtd" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x0f";
          options = [
            "SETENV"
            "NOPASSWD"
          ];
        }
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x11";
          options = [
            "SETENV"
            "NOPASSWD"
          ];
        }
      ];
    }
  ];

  users.groups.libvirtd.members = [
    "root"
    "stefan"
  ];
  users.groups.kvm.members = [
    "root"
    "stefan"
    "qemu-libvirtd"
  ];

  # libvirtd always burns its internal 30s drain wait before giving up ("Make forcefull daemon
  # shutdown", exit 1), which is dead time on every poweroff. Guests are already handled by
  # libvirt-guests, which stops first, so cut it short.
  systemd.services.libvirtd.serviceConfig.TimeoutStopSec = "5s";

  virtualisation.libvirtd = {
    # Resuming happens before anyone logs in, so a guest with a user-session audio backend fails
    # here and takes libvirt-guests down with it — leaving no live unit to save guests at
    # poweroff, which is how they ended up SIGKILLed. Resume by hand instead.
    onBoot = "ignore";
    onShutdown = "shutdown";
    shutdownTimeout = 60;
  };

  environment.systemPackages = with pkgs; [
    python313Packages.virt-firmware
    # fetch-macOS-v2.py + qemu-img init, to bootstrap a fresh OSX-KVM dir.
    inputs.osx-kvm.packages.${pkgs.stdenv.hostPlatform.system}.fetch-basesystem
  ];
}
