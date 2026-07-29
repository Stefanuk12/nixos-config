# Second Roblox VM: win11-rblx with its own uuid/MAC/vars/disk/serial. Shares CPU pinning and
# Looking Glass, so don't co-run. Create the disk with
# `cp --reflink=auto win11-rblx.qcow2 win11-rblx-2.qcow2`.

{ config }:

import ../lib/mkGamingVM.nix { inherit config; } {
  name = "win11-rblx-2";
  uuid = "f2e3f911-de68-4487-ac10-09e30619ad38";
  varsPath = /var/lib/libvirt/qemu/nvram/win11-rblx-2_VARS.fd;
  diskFile = /var/lib/libvirt/images/win11-rblx-2.qcow2;
  serial = "DB6B8A00F99F253DC9B0";
  mac = "52:54:3a:3e:04:b0";
}
