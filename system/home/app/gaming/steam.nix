{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mangohud
    lutris
  ];

  # Keep CPU cores at max clocks; powersave mid-game causes frame drops.
  powerManagement.cpuFreqGovernor = "performance";

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Raises game priority and pins governor/GPU to max while a game runs.
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
