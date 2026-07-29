{ pkgs, ... }:

{
  # Also what noctalia's battery and power-profile widgets read.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  # power-profiles-daemon always comes up on "balanced" — it has no persistence and no NixOS
  # option for a default — so pin it. This only runs at boot, so switching profiles by hand or
  # from noctalia's control centre afterwards still sticks.
  systemd.services.power-profile-performance = {
    description = "Pin the power profile to performance";
    after = [ "power-profiles-daemon.service" ];
    wants = [ "power-profiles-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
    };
  };
}
