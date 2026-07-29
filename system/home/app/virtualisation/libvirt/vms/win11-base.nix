# Base-image VM (16G, evdev input passthrough for first install) via ../lib/mkGamingVM.nix.

{ config }:

import ../lib/mkGamingVM.nix { inherit config; } {
  name = "win11-base";
  uuid = "cad4ffc1-bd63-4faa-b0af-9f6740589f32";
  diskFile = /var/lib/libvirt/images/win11-base.qcow2;
  serial = "ECFE037C590CE21A24AE";
  mac = "52:54:3a:20:c8:5d";

  memory = 16;

  # Needed on first install, or when Looking Glass Host isn't on the guest yet. by-id paths only —
  # eventN numbers shift with probe order across reboots and replugs.
  evdev = [
    { dev = "/dev/input/by-id/usb-Razer_Razer_BlackWidow_V4_75_-event-kbd"; }  # keyboard
    { dev = "/dev/input/by-id/usb-Razer_Razer_Viper_V3_Pro-event-mouse";       # mouse
      grab = "all"; grabToggle = "ctrl-ctrl"; repeat = true; }
  ];
}
