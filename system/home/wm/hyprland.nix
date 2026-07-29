{ pkgs, inputs, ... }:

{
  imports = [
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # The agent itself is noctalia's (programs.noctalia.settings.shell.polkit_agent).
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Noctalia's battery, network and power-profile widgets read these.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;

  services.gvfs.enable = true;
  services.libinput.enable = true;
  programs.dconf.enable = true;
  programs.zsh.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  boot.supportedFilesystems = [ "ntfs" ];
}
