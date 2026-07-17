# Second Roblox VM — same shared config as win11-rblx with unique uuid/MAC/vars/disk/serial; shares CPU pinning + Looking Glass so don't co-run, and create the disk first with `cp --reflink=auto win11-rblx.qcow2 win11-rblx-2.qcow2`.

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "win11-rblx-2";
  uuid = "f2e3f911-de68-4487-ac10-09e30619ad38";
  varsPath = /var/lib/libvirt/qemu/nvram/win11-rblx-2_VARS.fd;
  diskFile = /var/lib/libvirt/images/win11-rblx-2.qcow2;
  serial = "DB6B8A00F99F253DC9B0";
  mac = "52:54:3a:3e:04:b0";
}
