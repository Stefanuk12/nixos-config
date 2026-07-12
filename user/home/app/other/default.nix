{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./dolphin.nix
    ./getmedia.nix
    ./jdownloader.nix
    ./kde_connect.nix
    ./libreoffice.nix
    ./nixfmt.nix
    ./obs_studio.nix
    ./spotify_notify.nix
    ./stremio.nix
    ./winapps
  ];
}
