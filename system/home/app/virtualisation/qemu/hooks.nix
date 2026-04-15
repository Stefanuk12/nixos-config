{ lib, pkgs, ... }:

{
  systemd.services."libvirt-nosleep@" = {
    script = ''
      systemd-inhibit --what=sleep --why="Libvirt domain \"%i\" is running" --who=%U --mode=block sleep infinity
    '';
  };
  virtualisation.libvirtd.hooks.qemu = {
    "hugepages" = lib.getExe (
      pkgs.writeShellApplication {
        name = "qemu-hugepages-hook";

        runtimeInputs = [
          pkgs.coreutils
        ];

        text = ''
          GUEST_NAME="$1"
          ACTION="$2"

          # 16 × 1GB pages for 16GB VM RAM
          HUGEPAGES=16

          if [ "$ACTION" = "prepare" ]; then
            # Drop caches to maximise contiguous memory for 1G pages
            sync
            echo 3 > /proc/sys/vm/drop_caches
            echo "Allocating $HUGEPAGES × 1G hugepages for $GUEST_NAME..."
            echo "$HUGEPAGES" > /proc/sys/vm/nr_hugepages
            ALLOC=$(cat /proc/sys/vm/nr_hugepages)
            if [ "$ALLOC" -lt "$HUGEPAGES" ]; then
              echo "ERROR: Only allocated $ALLOC/$HUGEPAGES hugepages — releasing and aborting" >&2
              echo 0 > /proc/sys/vm/nr_hugepages
              exit 1
            fi
          fi

          if [ "$ACTION" = "release" ]; then
            echo "Releasing hugepages for $GUEST_NAME..."
            echo 0 > /proc/sys/vm/nr_hugepages
          fi
        '';
      }
    );
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

          if [ "$command" = "prepare" ]; then
            systemctl start libvirt-nosleep@"$object"
          elif [ "$command" = "started" ]; then
            systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,8,9
            systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,8,9
            systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,8,9
          elif [ "$command" = "release" ]; then
            systemctl stop libvirt-nosleep@"$object"
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-15
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-15
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-15
          fi
        '';
      }
    );
  };
}
