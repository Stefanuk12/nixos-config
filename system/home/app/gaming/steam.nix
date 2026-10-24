{ inputs, pkgs, ... }:

let
  gpuEnv = import ../../../../hosts/home/gpu-env.nix;
  sls = inputs.sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.sls-steam;
in
{
  environment.systemPackages = [
    pkgs.mangohud
    (gpuEnv.onDgpu pkgs pkgs.lutris)
  ];

  # powersave mid-game causes frame drops.
  powerManagement.cpuFreqGovernor = "performance";

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
    enable = true;
    # pin_cores confines games to the V-Cache CCD on the 9950X3D, so Wine fails any
    # SetThreadAffinityMask covering all cores; Elden Ring's Wwise init dies on that.
    settings.cpu.pin_cores = "no";
  };

  programs.steam = {
    enable = true;

    # Games inherit the FHS env, so this covers the whole library without per-appid launch options.
    package = pkgs.steam.override {
      extraProfile = gpuEnv.preferDgpu;
      extraEnv.LD_AUDIT = "${sls}/library-inject.so:${sls}/SLSsteam.so";
    };

    # Valve's Protons ship no winewayland, so PROTON_ENABLE_WAYLAND=1 is a no-op on them.
    extraCompatPackages = [ pkgs.proton-ge-bin ];

    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    gamescopeSession.enable = true;
    localNetworkGameTransfers.openFirewall = true;
  };
}
