{ pkgs, ... }:

{
  services.udev.packages = [ pkgs.boxflat ];
}
