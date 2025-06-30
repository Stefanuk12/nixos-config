{
  config,
  lib,
  pkgs,
  hostName,
  ...
}: let
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  kbLayout = "us";
  systemSettings = config.systemSettings;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../system/common/font.nix
    ../../system/common/settings.nix
    ../../system/${hostName}
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Setup networking
  networking.hostName = hostName; # Define your hostname.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = timeZone;

  # Select internationalisation properties.
  i18n.defaultLocale = locale;

  # Configure keymap in X11
  console.useXkbConfig = true;

  # Enable PipeWire - screenshare + sound
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # MIME Setup
  xdg.mime.defaultApplications = {
    "text/html" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/about" = "firefox.desktop";
    "x-scheme-handler/unknown" = "firefox.desktop";
  };

  environment.systemPackages = with pkgs; [
    pinentry
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.stefan = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
    ];
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];
  system.stateVersion = "23.05";
}
