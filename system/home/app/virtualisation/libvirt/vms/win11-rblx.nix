# Roblox gaming VM. Shared config lives in ../lib/mkGamingVM.nix; to enable
# evdev input passthrough pass an `evdev` list (see win11-base.nix).

# NOTE FOR FUTURE SELF: to base image, consider installing openssh server, then also running the clean qemu script
# you should install kde connect on this + looking glass host too

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "win11-rblx";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f31";
  diskFile = /var/lib/libvirt/images/win11-rblx.qcow2;
  serial = "ECFE037C590CE21A24AE";
  mac = "52:54:3a:20:c8:5d";
}
