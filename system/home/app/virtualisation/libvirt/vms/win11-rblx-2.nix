# Second Roblox VM — same shared config as win11-rblx, only the unique
# fields (uuid, MAC, nvram vars path, disk image, serial) differ.
#
# Shares the same CPU pinning and Looking Glass /dev/kvmfr0 as win11-rblx,
# so do NOT run them at the same time. Before first boot, create the disk:
#   sudo cp --reflink=auto /var/lib/libvirt/images/win11-rblx.qcow2 \
#                          /var/lib/libvirt/images/win11-rblx-2.qcow2

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "win11-rblx-2";
  uuid = "f2e3f911-de68-4487-ac10-09e30619ad38";
  varsPath = /var/lib/libvirt/qemu/nvram/win11-rblx-2_VARS.fd;
  diskFile = /var/lib/libvirt/images/win11-rblx-2.qcow2;
  serial = "DB6B8A00F99F253DC9B0";
  mac = "52:54:3a:3e:04:b0";
}
