{ lib, pkgs, ... }:

{
  virtualisation.libvirtd.hooks.qemu = {
    "cpu-isolate" = lib.getExe (
      pkgs.writeShellApplication {
        name = "qemu-hook";

        runtimeInputs = [
          pkgs.systemd
        ];

        text = ''
          #!/bin/sh

          command=$2

          if [ "$command" = "started" ]; then
            systemctl set-property --runtime -- system.slice AllowedCPUs=0,1,8,9
            systemctl set-property --runtime -- user.slice AllowedCPUs=0,1,8,9
            systemctl set-property --runtime -- init.scope AllowedCPUs=0,1,8,9
          elif [ "$command" = "release" ]; then
            systemctl set-property --runtime -- system.slice AllowedCPUs=0-15
            systemctl set-property --runtime -- user.slice AllowedCPUs=0-15
            systemctl set-property --runtime -- init.scope AllowedCPUs=0-15
          fi
        '';
      }
    );
  };
}

