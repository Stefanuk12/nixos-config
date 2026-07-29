{ config, pkgs, ... }:

{
  imports = [ ./mt7927-bt.nix ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Name = "stefan_pc";
        # Loudspeaker, so iOS/Android list this PC in their output picker — a "Computer" major
        # class is filtered out of iOS's.
        Class = "0x240414";
        Experimental = true;
        Discoverable = false;
        Pairable = true;
      };
      Policy = {
        AutoEnable = true;
      };
    };
  };

  services.pipewire.wireplumber.extraConfig = {
    "51-bluez-a2dp-sink" = {
      "monitor.bluez.properties" = {
        "bluez5.roles" = [
          "a2dp_sink"
          "hfp_ag"
          "hfp_hf"
        ];
        "bluez5.codecs" = [
          "sbc"
          "aac"
          "ldac"
          "aptx"
          "aptx_hd"
        ];
        "bluez5.autoswitch-profile" = true;
        "bluez5.enable-sbc-xq" = true;
      };
    };
  };

  # The rfkill device only appears ~25s into boot, after bt-unblock has run, so it comes up
  # soft-blocked. Unblocking on device-add is race-free.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="rfkill", ATTR{type}=="bluetooth", ATTR{soft}="0"
  '';

  # systemd-rfkill persists a soft block across reboots, overriding powerOnBoot/AutoEnable.
  systemd.services.bt-unblock = {
    description = "Clear persisted Bluetooth rfkill soft block on boot";
    after = [ "systemd-rfkill.service" ];
    wants = [ "systemd-rfkill.service" ];
    before = [ "bluetooth.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
  };

  systemd.services.bt-agent = {
    description = "Bluetooth agent for auto-pairing";
    after = [ "bluetooth.service" ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.bluez-tools}/bin/bt-agent -c NoInputNoOutput";
      Restart = "on-failure";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
