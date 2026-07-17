{ lib, pkgs, ... }:

let
  # Single source of truth for the host-reserved cpuset (the VM builders read
  # the same file for emulatorpin/iothreadpin), so the hook can't drift from it.
  hostCores = (import ../libvirt/lib/pinning.nix).hostCores;
in
{
  systemd.services."libvirt-nosleep@" = {
    script = ''
      systemd-inhibit --what=sleep --why="Libvirt domain \"%i\" is running" --who=%U --mode=block sleep infinity
    '';
  };
  virtualisation.libvirtd.hooks.qemu = {
    "cpu-isolate" = lib.getExe (
      pkgs.writeShellApplication {
        name = "qemu-hook";

        runtimeInputs = [
          pkgs.systemd
        ];

        text = ''
          #!/bin/sh

          object=$1
          command=$2

          # Only the CPU-pinned VMs (mkGamingVM guests + osx-kvm-gpu) isolate host slices onto hostCores; unpinned guests must leave the host on all cores.
          case "$object" in
            win11-base|win11-rblx|win11-rblx-2|gaming|osx-kvm-gpu) pinned=1 ;;
            *) pinned=0 ;;
          esac

          if [ "$command" = "prepare" ]; then
            systemctl start libvirt-nosleep@"$object"
          elif [ "$command" = "started" ] && [ "$pinned" = 1 ]; then
            systemctl set-property --runtime -- system.slice AllowedCPUs=${hostCores}
            systemctl set-property --runtime -- user.slice AllowedCPUs=${hostCores}
            systemctl set-property --runtime -- init.scope AllowedCPUs=${hostCores}
          elif [ "$command" = "release" ]; then
            systemctl stop libvirt-nosleep@"$object"
            if [ "$pinned" = 1 ]; then
              systemctl set-property --runtime -- system.slice AllowedCPUs=0-15
              systemctl set-property --runtime -- user.slice AllowedCPUs=0-15
              systemctl set-property --runtime -- init.scope AllowedCPUs=0-15
            fi
          fi
        '';
      }
    );

    # Defragment memory before a domain starts so on-demand 2MB hugepages (see domains.nix) can allocate on a fragmented host; both steps are safe and non-destructive.
    "hugepage-defrag" = lib.getExe (
      pkgs.writeShellApplication {
        name = "qemu-hugepage-defrag";

        runtimeInputs = [
          pkgs.coreutils
        ];

        text = ''
          #!/bin/sh

          command=$2

          if [ "$command" = "prepare" ]; then
            sync
            echo 3 > /proc/sys/vm/drop_caches || true
            echo 1 > /proc/sys/vm/compact_memory || true
          fi
        '';
      }
    );
  };
}
