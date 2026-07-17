# Roblox gaming VM via ../lib/mkGamingVM.nix; pass an `evdev` list to enable input passthrough (see win11-base.nix).

# TODO: on the base image install openssh server + KDE Connect + Looking Glass Host, then run the clean qemu script.

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "win11-rblx";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f31";
  diskFile = /var/lib/libvirt/images/win11-rblx.qcow2;
  serial = "ECFE037C590CE21A24AE";
  mac = "52:54:3a:20:c8:5d";
}
