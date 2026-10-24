# Rust VM: overlay on win11-base.qcow2, grown to 160G since the base's 64G can't fit Rust + its
# updates. Shares CPU pinning and Looking Glass with the other gaming VMs, so don't co-run.
# Create the disk with
# `qemu-img create -f qcow2 -F qcow2 -b /var/lib/libvirt/images/win11-base.qcow2 -o cluster_size=2M /var/lib/libvirt/images/win11-rust.qcow2 160G`,
# then extend C: into the new space from inside the guest.

{ config, pkgs }:

import ../lib/mkGamingVM.nix { inherit config pkgs; } {
  name = "win11-rust";
  uuid = "a20d4f9b-540c-4f7b-8a2f-5e482debea9e";
  varsPath = /var/lib/libvirt/qemu/nvram/win11-rust_VARS.fd;
  diskFile = /var/lib/libvirt/images/win11-rust.qcow2;
  serial = "C9338383EEF14AD757DB";
  mac = "52:54:3a:46:63:97";

  memory = 16;
}
