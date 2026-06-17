# Base-image VM: 16G / 1GB hugepages, with evdev input passthrough wired up
# for first install. Shared config lives in ../lib/mkGamingVM.nix.

{ inputs, pkgs }:

import ../lib/mkGamingVM.nix { inherit inputs pkgs; } {
  name = "win11-base";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f32";
  diskFile = /var/lib/libvirt/images/win11-base.qcow2;
  serial = "ECFE037C590CE21A24AE";
  mac = "52:54:3a:20:c8:5d";

  memory = 16;
  hugepages = { enable = true; size = 1; unit = "G"; };  # 1GB pages

  # Direct host input passthrough via evdev — lower latency than USB, only
  # needed on first install / when Looking Glass Host isn't on the guest
  # (find devices with: ls -l /dev/input/by-id/).
  evdev = [
    { dev = "/dev/input/event1"; }                                        # keyboard
    { dev = "/dev/input/event6"; grab = "all"; grabToggle = "ctrl-ctrl";  # mouse
      repeat = true; }
  ];
}
