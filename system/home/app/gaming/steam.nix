{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mangohud
    lutris
  ];

  # powersave mid-game causes frame drops.
  powerManagement.cpuFreqGovernor = "performance";

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
