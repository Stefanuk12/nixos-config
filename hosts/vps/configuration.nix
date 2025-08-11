{ config, lib, pkgs, hostName, ... }:

let
  timeZone = "Europe/London";
  locale = "en_GB.UTF-8";
  kbLayout = "us";
  systemSettings = config.systemSettings;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  imports =
    [
      ./hardware-configuration.nix
      ../../system/common/settings.nix
      ../../system/${hostName}
    ];

  # Use systemd
  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  systemd.targets.multi-user.enable = true;
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  # Setup networking
  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = timeZone;

  # Select internationalisation properties.
  i18n.defaultLocale = locale;

  # Configure keymap in X11
  services.xserver.xkb.layout = kbLayout;
  console.keyMap = kbLayout;

  # Disable sound.
  services.pulseaudio.enable = false;

  # Disable autologin.
  services.getty.autologinUser = null;

  # Disable root login
  security.sudo.enable = true;
  security.pam.sshAgentAuth.enable = true;
  security.pam.services.sudo.sshAgentAuth = true;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
    settings.X11Forwarding = false;
    settings.AllowAgentForwarding = "no";
    settings.AllowTcpForwarding = "no";
    settings.MaxAuthTries = 3;
    settings.ClientAliveInterval = 300;
    settings.ClientAliveCountMax = 2;
  };

  # Define a user account
  users.mutableUsers = false;
  users.users.stefan = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "libvirtd" ];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
      systemSettings.sshKeys."stefan@windows-pc"
    ];
  };

  # Enable passwordless sudo.
  security.sudo.extraRules = [
    {
      users = ["stefan" ];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  # Disable documentation for minimal install.
  documentation.enable = false;

  # Systemd-journald limits (avoid log bloat)
  systemd.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=200M
    MaxFileSec=1month
  '';

  # Disable core dumps to save space / reduce info exposure
  systemd.coredump.enable = false;

  # Basic network sysctl hardening
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
  };

  # Time sync (explicit)
  services.timesyncd.enable = true;

  # Nix store maintenance
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  # Auto upgrade
  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = null;
  };

  # Misc
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "23.05";
}
