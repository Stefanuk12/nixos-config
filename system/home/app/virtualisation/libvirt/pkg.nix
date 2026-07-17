{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # remove need for sudo auth when switching inputs
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

  environment.systemPackages = with pkgs; [
    python313Packages.virt-firmware
    # Wraps fetch-macOS-v2.py + qemu-img init (from the osx-kvm flake) to bootstrap a fresh OSX-KVM dir declaratively.
    inputs.osx-kvm.packages.${pkgs.stdenv.hostPlatform.system}.fetch-basesystem
  ];
}
