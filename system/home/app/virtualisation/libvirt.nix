{ pkgs, inputs, config, ... }:

{
  imports = [
    inputs.nixos-vfio.nixosModules.vfio
    ./qemu.nix
  ];

  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = [ "eth0" ];
    };
  };

  security.sudo.extraRules = [
    {
      groups = [ "libvirtd" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x0f";
          options = [ "SETENV" "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/ddcutil -d 2 setvcp 60 0x11";
          options = [ "SETENV" "NOPASSWD" ];
        }
      ];
    }
  ];

  virtualisation.libvirtd = {
    enable = true;
    clearEmulationCapabilities = false;
    qemuVerbatimConfig = ''
      nvram = [
        "/nix/store/v9x2ya2q7h001k70qwdpgsp6cnhwm6g8-OVMF-202402-fd/FV/OVMF_VARS.fd"
      ]
    '';
    qemu = {
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [pkgs.OVMFFull.fd];
      };
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
  virtualisation.kvmfr = {
    enable = true;
    
    devices = [
      {
        size = 64;

        permissions = {
          user = "stefan";
        };
      }
    ];
  };


  boot.extraModprobeConfig ="options vfio-pci ids=1002:73a5,1002:ab28";
  boot.kernelParams = [
    "iommu=pt"
    "kvm.ignore-msrs=1"
    "kvmfr.static_size_mb=32"
  ];
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
    "kvmfr"

    "i2c_dev"
    "ddcci_backlight"
  ];
  boot.extraModulePackages = [config.boot.kernelPackages.ddcci-driver];
  users.groups.libvirtd.members = [ "root" "stefan" ];
  users.groups.kvm.members = [ "root" "stefan" ];

  hardware.opengl.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  # Looking Glass
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 stefan qemu-libvirtd -"
  ];
  environment.systemPackages = with pkgs; [
    looking-glass-client
    ddcutil
  ];
}
