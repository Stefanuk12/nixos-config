{ pkgs, ... }:

{
  programs.gpg.enable = true;
  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-qt;
    defaultCacheTtl = 3600; # seconds (1 hour)
    defaultCacheTtlSsh = 3600;
    maxCacheTtl = 7200; # max regardless of activity (2 hours)
    maxCacheTtlSsh = 7200;
  };
  home.sessionVariables = {
    SSH_AUTH_SOCK = "$(gpgconf --list-dirs agent-ssh-socket)";
  };
}
