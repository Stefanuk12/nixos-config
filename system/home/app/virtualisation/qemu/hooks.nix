{ lib, pkgs, ... }:

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

    # Defragment memory before a domain starts. Our on-demand 2MB hugepages
    # (see domains.nix) otherwise fail to allocate once host memory is
    # fragmented; compact_memory rebuilds high-order blocks and drop_caches
    # frees page cache pinning them. Both are safe and non-destructive.
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
