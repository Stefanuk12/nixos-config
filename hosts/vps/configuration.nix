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
  kbLayout = "us";
  systemSettings = config.systemSettings;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../system/common/settings.nix
    ../../system/${hostName}
  ];

  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  systemd.targets.multi-user.enable = true;
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/boot";
  };

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  time.timeZone = timeZone;

  i18n.defaultLocale = locale;

  services.xserver.xkb.layout = kbLayout;
  console.keyMap = kbLayout;

  services.pulseaudio.enable = false;

  services.getty.autologinUser = null;

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

  users.mutableUsers = false;
  users.users.stefan = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
    ];
    openssh.authorizedKeys.keys = [
      systemSettings.sshKeys."stefan@home"
      systemSettings.sshKeys."stefan@windows-pc"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "stefan" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  documentation.enable = false;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    RuntimeMaxUse=200M
    MaxFileSec=1month
  '';

  systemd.coredump.enable = false;

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

  services.timesyncd.enable = true;

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  system.autoUpgrade = {
    enable = true;
    allowReboot = false;
    flake = "github:Stefanuk12/nixos-config#vps";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  system.stateVersion = "23.05";
}
