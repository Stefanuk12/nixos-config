{ pkgs, inputs, ... }:

{
  imports = [
    inputs.nixos-vfio.nixosModules.vfio
  ];

  networking.interfaces.eth0.useDHCP = true;
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = [ "eth0" ];
    };
  };

  virtualisation.libvirtd = {
    enable = true;
    qemuVerbatimConfig = ''
      nvram = [
        "/nix/store/v9x2ya2q7h001k70qwdpgsp6cnhwm6g8-OVMF-202402-fd/FV/OVMF_VARS.fd"
      ]
    '';
    qemu = {
      package = pkgs.qemu_kvm;
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
        size = 32;

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
  ];
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
  ];
}
