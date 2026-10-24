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
  # wineasio mlockall()s FL Studio, so with the 8 MiB default every later thread stack fails to
  # map and pipewire-jack can't start. Set on the system manager too: user@ inherits its hard cap.
  systemd.settings.Manager.DefaultLimitMEMLOCK = "infinity";
  systemd.user.settings.Manager.DefaultLimitMEMLOCK = "infinity";

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
  # At the defaults (32 jobs × all 32 threads) a batch of local C++ builds — wine, dolphin, libjxl —
  # exhausts RAM and the global OOM killer takes out the Hyprland session instead of cc1plus.
  nix.settings.max-jobs = 4;
  nix.settings.cores = 8;
  # Builders inherit this, so any OOM that still happens lands on a build, not the desktop.
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 1000;
  # 25.05, not 23.05: hydenix used to force this value, so lowering it on its removal would
  # silently change service defaults on an already-installed system.
  system.stateVersion = "25.05";
}
