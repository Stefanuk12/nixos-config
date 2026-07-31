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

  # Headroom for xdph's dmabuf fd leak, which the overlay patch in flake.nix fixes: on the 1024-fd
  # default the margin between "leaking" and "screen sharing is broken" was about a day of uptime.
  # Belt and braces — the patch is the actual fix.
  systemd.user.services.xdg-desktop-portal-hyprland = {
    overrideStrategy = "asDropin";
    serviceConfig.LimitNOFILE = 65536;
  };

  # The agent itself is noctalia's (programs.noctalia.settings.shell.polkit_agent).
  security.polkit.enable = true;
  security.rtkit.enable = true;

  services.gvfs.enable = true;
  services.libinput.enable = true;
  programs.dconf.enable = true;
  programs.zsh.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  boot.supportedFilesystems = [ "ntfs" ];
}
