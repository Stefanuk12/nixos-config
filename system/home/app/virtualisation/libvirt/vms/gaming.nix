# PSVR2 + SteamVR guest on the non-hardened profile (Hyper-V on, hypervisor visible). Shares the
# passthrough dGPU and Looking Glass, so never run it alongside win11-base/rblx/rblx-2.

{ config }:

import ../lib/mkGamingVM.nix { inherit config; } {
  name = "gaming";
  uuid = "6b78bf45-54fa-4b41-a59d-0dc28238e512";
  diskFile = /var/lib/libvirt/images/gaming.qcow2;
  varsPath = /var/lib/libvirt/qemu/nvram/gaming_VARS.fd; # own nvram, not the shared win11_VARS.fd
  serial = "CA02B951469E16C91DDA";
  mac = "52:54:00:6d:59:8f";

  memory = 16;
  hardened = false;

  # PSVR2 (054c:0cde) — libvirt reads these ints base-0.
  usb = [ { vendor = 1356; product = 3294; } ];
}
