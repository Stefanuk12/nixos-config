{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./jdownloader.nix
    ./kde_connect.nix
    ./libreoffice.nix
    ./nixfmt.nix
    ./obs_studio.nix
    ./spotify.nix
    ./stremio.nix
    ./winapps
  ];
}
