{ inputs, pkgs, ... }:

{
  services.flatpak.packages = [
    "com.stremio.Stremio"
    "com.stremio.Service"
  ];
}
