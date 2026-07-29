{
  config,
  lib,
  pkgs,
  hostName,
  ...
}:
let
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  systemSettings = config.systemSettings;
  hw = import ./hardware-profile.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../system/common/font.nix
    ../../system/common/settings.nix
    ../../system/${hostName}
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = lib.mkDefault hostName;
  networking.networkmanager.enable = true;

  # Every real interface is an externally-managed bridge, so NetworkManager parks connectivity at
  # "limited" (Spotify and friends go offline) unless given a reachable check URI.
  environment.etc."NetworkManager/conf.d/connectivity.conf".text = ''
    [connectivity]
    uri=http://nmcheck.gnome.org/check_network_status.txt
    interval=300
  '';

  time.timeZone = lib.mkDefault timeZone;

  i18n.defaultLocale = lib.mkDefault locale;

  console.useXkbConfig = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Master switch for the proprietary NVIDIA driver — without "nvidia" here the hardware.nvidia
  # block below is inert and dgpu-enable leaves the card driverless. Drop it on an AMD dGPU swap.
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    powerManagement.enable = false;
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
 
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      amdgpuBusId = hw.igpu.primeBusId; # iGPU drives the display
      nvidiaBusId = hw.dgpu.primeBusId; # dGPU is the offload target
    };  
  };

  users.users.stefan = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # 25.05, not 23.05: hydenix used to force this value, so lowering it on its removal would
  # silently change service defaults on an already-installed system.
  system.stateVersion = "25.05";
}
