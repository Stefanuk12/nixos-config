# "gaming" VM — VR-optimized Windows 11 guest for PSVR2 + SteamVR.
#
# Shares the hardened gaming VMs' infrastructure (6950 XT passthrough, CPU
# pinning, Looking Glass, br0) via ../lib/mkGamingVM.nix, but runs the
# non-hardened profile (hardened = false): Hyper-V enlightenments ON and the
# hypervisor left visible, which SteamVR/PSVR2 runtimes prefer over the
# anti-cheat concealment the Roblox VMs use.
#
# Passthrough:
#   - dGPU (03:00.0 + 03:00.1) — vfio-bound at boot; the PSVR2 PC adapter's
#     DisplayPort plugs physically into this card, so headset video "just
#     works" through the GPU passthrough. Only the USB side is declared here.
#   - PSVR2 USB (Sony 054c:0cde → ints 1356/3294). Must be powered on before
#     the VM starts (no startupPolicy in nixvirt) or hotplug it afterwards
#     with `virsh -c qemu:///system attach-device gaming <usb.xml>`.
#
# Like the other GPU VMs it shares the dGPU / Looking Glass, so do NOT run it
# at the same time as win11-base/rblx/rblx-2. It has its own disk + nvram.

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "gaming";
  uuid = "6b78bf45-54fa-4b41-a59d-0dc28238e512";
  diskFile = /var/lib/libvirt/images/gaming.qcow2;
  varsPath = /var/lib/libvirt/qemu/nvram/gaming_VARS.fd;   # own nvram, not the shared win11_VARS.fd
  serial = "CA02B951469E16C91DDA";
  mac = "52:54:00:6d:59:8f";

  memory = 16;
  hardened = false;   # VR/perf profile

  # Sony PlayStation VR2 (USB id 054c:0cde). libvirt reads these ints base-0,
  # so 1356 → 0x054c and 3294 → 0x0cde.
  usb = [ { vendor = 1356; product = 3294; } ];
}
