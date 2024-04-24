
{ pkgs, ... }:

{
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
  };

  boot.initrd.preDeviceCommands = ''
    DEVS="0000:03:00.0 0000:03:00.1"

    for DEV in $DEVS; do
      echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
    done
    modprobe -i vfio-pci
  '';

  boot.kernelParams = [
    "iommu=pt"
    "kvm.ignore-msrs=1"
  ];
  boot.initrd.kernelModules = [
    "vfio_pci"
    "vfio"
    "vfio_iommu_type1"
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
