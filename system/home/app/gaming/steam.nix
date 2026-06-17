{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mangohud # Performance monitoring overlay for games
    lutris # Game manager for Linux
  ];

  # Keep all CPU cores at max clocks while gaming (avoids cores
  # dropping into powersave mid-game and causing frame drops)
  powerManagement.cpuFreqGovernor = "performance";

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Raises game process priority and pins governor/GPU to max while
  # a game runs. Won't multithread a single-threaded game, but keeps
  # the main thread from being interrupted by background work.
  programs.gamemode.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
