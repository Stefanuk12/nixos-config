{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./dolphin.nix
    ./jdownloader.nix
    ./kde_connect.nix
    ./libreoffice.nix
    ./nixfmt.nix
    ./obs_studio.nix
    ./stremio.nix
    ./winapps
  ];
}
