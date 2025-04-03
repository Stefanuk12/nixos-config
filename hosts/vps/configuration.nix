{ config, lib, pkgs, hostName, ... }:

let
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  kbLayout = "us";
  systemSettings = config.systemSettings;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
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
  networking.firewall.enable = true;

  # Set your time zone.
  time.timeZone = timeZone;

  # Select internationalisation properties.
  i18n.defaultLocale = locale;

  # Configure keymap in X11
  services.xserver.xkb.layout = kbLayout;
  console.keyMap = kbLayout;

  # Disable sound.
  # sound.enable = true;
  services.pulseaudio.enable = false;

  # Enable root login
  security.sudo.enable = true;
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };
  users.users.root.openssh.authorizedKeys.keys = [
    systemSettings.sshKeys."stefan@home"
    systemSettings.sshKeys."stefan@windows-pc"
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.stefan = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ] ++ ifTheyExist [ "minecraft" ];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
      systemSettings.sshKeys."stefan@windows-pc"
    ];
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "23.05";
}
