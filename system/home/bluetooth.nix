{ config, pkgs, ... }:

{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Name = "stefan_pc";
        # Advertise as a loudspeaker (0x240414) so iOS/Android list this PC in their audio output picker and stream A2DP to it; a "Computer" major class is filtered out of iOS's picker.
        Class = "0x240414";
        Experimental = true;
        Discoverable = false;
        Pairable = true;
        # Enable = "Source,Sink,Media,Socket"; # this actually just breaks my a2dp sink
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

  # systemd-rfkill persists a soft block across reboots, overriding powerOnBoot/AutoEnable; clear it after rfkill state is restored.
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
