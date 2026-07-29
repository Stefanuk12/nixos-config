{ username, pkgs, ... }:

{
  hardware.openrazer.enable = true;
  users.users.stefan.extraGroups = [ "openrazer" ];
  environment.systemPackages = with pkgs; [
    openrazer-daemon
    polychromatic
  ];
}