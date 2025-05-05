{
  pkgs,
  inputs,
  config,
  lib,
  ...
}: {
  imports = [
    inputs.nixos-vfio.nixosModules.vfio
    ./qemu
    ./xml
  ];

  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = ["eth0"];
    };
  };

  # remove need for sudo auth when switching inputs
  security.sudo.extraRules = [
    {
      groups = ["libvirtd"];
      commands = [
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x0f";
          options = ["SETENV" "NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x11";
          options = ["SETENV" "NOPASSWD"];
        }
      ];
    }
  ];

  virtualisation.libvirtd = {
    enable = true;
    clearEmulationCapabilities = false;
    qemu = {
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [pkgs.OVMFFull.fd];
      };
      verbatimConfig = ''
        nvram = [
          "/nix/store/v9x2ya2q7h001k70qwdpgsp6cnhwm6g8-OVMF-202402-fd/FV/OVMF_VARS.fd"
        ]
      '';
    };
    deviceACL = [
      "/dev/null"
      "/dev/full"
      "/dev/zero"
      "/dev/random"
      "/dev/urandom"
      "/dev/ptmx"
      "/dev/kvm"
      "/dev/kqemu"
      "/dev/rtc"
      "/dev/hpet"
      "/dev/net/tun"
    ];
  };

  users.groups.libvirtd.members = ["root" "stefan"];
  users.groups.kvm.members = ["root" "stefan"];
}
