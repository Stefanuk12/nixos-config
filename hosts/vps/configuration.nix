{ config, lib, pkgs, hostName, ... }:

let
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  kbLayout = "us";
  systemSettings = config.systemSettings;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../system/common/settings.nix
      ../../system/${hostName}
    ];

  # Use the grub EFI boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";  

  # Setup networking
  networking.hostName = hostName; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    networks."10-internet" = {
      matchConfig.MACAddress = "00:50:56:45:1a:e6"; # Interface MAC address here
      linkConfig.RequiredForOnline = "routable";

      address = [
        "38.242.201.72/24" # Your server IPv4 address here
        # "2a02:c206:2078:9036:0000:0000:0000:0001/64" # Your server IPv6 address here
      ];
      routes = [
          {
            routeConfig = {
                Gateway = "38.242.192.1"; # Your gateway address here
                GatewayOnLink = true;
            };
          }
          # {
          #   routeConfig = {
          #       Gateway = "fe80::1"; # This should be correct as is
          #       GatewayOnLink = true;
          #   };
          # }
      ];
      dns = [
        "161.97.189.52"
        "161.97.189.51"
        # "2a02:c206:5028::2:53"
        # "2a02:c206:5028::1:53"
      ];
    };
  };

  # Set your time zone.
  time.timeZone = timeZone;

  # Select internationalisation properties.
  i18n.defaultLocale = locale;

  # Configure keymap in X11
  services.xserver.xkb.layout = kbLayout;
  console.keyMap = kbLayout;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # Enable root login
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    systemSettings.sshKeys."stefan@home"
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.stefan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "23.05";
}
