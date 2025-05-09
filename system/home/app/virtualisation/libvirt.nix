{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  secureBootOVMF = pkgs.OVMF.override {
    secureBoot = true;
    # msVarsTemplate = true;
    tpmSupport = true;
    tlsSupport = true;
  };
in {
  imports = [
    # inputs.nixvirt.nixosModules.default
    ./qemu
    # ./xml
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

  virtualisation.libvirtd.qemu = {
    runAsRoot = true;
    swtpm.enable = true;
    ovmf = {
      enable = true;
      packages = [secureBootOVMF.fd];
    };
    verbatimConfig = ''
      nvram = [
        "/run/libvirt/nix-ovmf/OVMF_VARS.fd"
      ]
    '';
  };

  users.groups.libvirtd.members = ["root" "stefan"];
  users.groups.kvm.members = ["root" "stefan"];

  environment.systemPackages = with pkgs; [
    python313Packages.virt-firmware
  ];
}
