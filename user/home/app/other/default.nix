{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./cli_tools.nix
    ./dolphin.nix
    ./fastfetch.nix
    ./getmedia.nix
    ./jdownloader.nix
    ./kde_connect.nix
    ./libreoffice.nix
    ./nixfmt.nix
    ./obs_studio.nix
    ./spicetify.nix
    ./spotify_notify.nix
    ./stremio.nix
    ./winapps
  ];
}
