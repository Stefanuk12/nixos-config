{ pkgs, lib, ... }:

let
  pciDevices = [
    "pci_0000_03_00_0"
    "pci_0000_03_00_1"
  ];
  passthroughDrivers = [
    "amdgpu"
  ];

  buildPciAttach = list: mode: lib.concatMapStringsSep "\n" (pci: "virsh nodedev-" + mode + " " + pci) list;
  buildModprobe = list: flag: lib.concatMapStringsSep "\n" (x: "modprobe -" + flag + " " + x) list;
in {
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
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [pkgs.OVMFFull.fd];
      };

      # Don't hook evdev at vm start - copied from Gerg-L
      package = pkgs.qemu_kvm.overrideAttrs (old: {
        patches = old.patches ++ [(builtins.toFile "qemu.diff" ''
          diff --git a/ui/input-linux.c b/ui/input-linux.c
          index e572a2e..a9d76ba 100644
          --- a/ui/input-linux.c
          +++ b/ui/input-linux.c
          @@ -397,12 +397,6 @@ static void input_linux_complete(UserCreatable *uc, Error **errp)
               }

               qemu_set_fd_handler(il->fd, input_linux_event, NULL, il);
          -    if (il->keycount) {
          -        /* delay grab until all keys are released */
          -        il->grab_request = true;
          -    } else {
          -        input_linux_toggle_grab(il);
          -    }
               QTAILQ_INSERT_TAIL(&inputs, il, next);
               il->initialized = true;
               return;
         '')];
      });
    };
  };

  # Looking Glass
  environment.systemPackages = with pkgs; [
    looking-glass-client
  ];
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 stefan qemu-libvirtd -"
  ];

  # Dynamic passthrough (depending on VM start/stop) - copied from Greg-L
  virtualisation.libvirtd.hooks.qemu = {
    "AAA" = lib.getExe (
      pkgs.writeShellApplication {
        name = "qemu-hook";

        runtimeInputs = [
          pkgs.libvirt
          pkgs.systemd
          pkgs.kmod
        ];

        text = ''
          GUEST_NAME="$1"
          OPERATION="$2"

          # Only works if our Windows machine is started
          if [ "$GUEST_NAME" != "Windows" ]; then
            exit 0
          fi

          if [ "$OPERATION" == "prepare" ]; then
              systemctl stop display-manager.service
              ${buildModprobe passthroughDrivers "r"}
              ${buildPciAttach pciDevices "detach"}
              systemctl start display-manager.service
          fi

          if [ "$OPERATION" == "release" ]; then
            systemctl stop display-manager.service
            ${buildPciAttach pciDevices "reattach"}
            ${buildModprobe passthroughDrivers "a"}
            systemctl start display-manager.service
          fi
        '';
      }
    );
  };

  # Setup passthrough
  boot.kernelParams = [
    "amd_iommu=on"
    "amd_iommu=pt"
    "kvm.ignore-msrs=1"
  ];
  # boot.postBootCommands = ''
  #   DEVS="0000:03:00.0 0000:03:00.1"
  #
  #   for DEV in $DEVS; do
  #     echo "vfio-pci" > /sys/bus/pci/devices/$DEV/driver_override
  #   done
  #   modprobe -i vfio-pci
  # '';
  
  boot.kernelModules = [ "vfio_pci" "vfio" "vfio_iommu_type1.allow_unsafe_interrupts=1"]
    ++ lib.optionals (lib.versionOlder pkgs.linux.version "6.2") [ "vfio_virqfd" ];
  
  users.groups.libvirtd.members = [ "root" "stefan" ];
}
