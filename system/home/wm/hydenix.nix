{ pkgs, inputs, ... }:

{
  imports = [
    inputs.hydenix.nixosModules.default

    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  hydenix = {
    enable = true;
    hostname = "home";
    timezone = "Europe/London";
    locale = "en_GB.UTF-8";

    boot.enable = false;
    network.enable = false;
    gaming.enable = false;
  };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  services.displayManager.sddm.wayland.compositorCommand = "kwin_wayland --drm-device=/dev/dri/card0";
  boot.supportedFilesystems = [ "ntfs" ];
}
