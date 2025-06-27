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
  };
}

