{ pkgs, inputs, config, lib, ... }:

{
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
    verbatimConfig = ''
      nvram = [
        "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
      ]

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
  };

  users.groups.libvirtd.members = ["root" "stefan"];
  users.groups.kvm.members = ["root" "stefan" "qemu-libvirtd"];

  environment.systemPackages = with pkgs; [
    python313Packages.virt-firmware
  ];
}
