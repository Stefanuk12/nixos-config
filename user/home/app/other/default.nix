{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./kde_connect.nix
    ./nixfmt.nix
    ./obs_studio.nix
    ./spotify.nix
    ./stremio.nix
    ./winapps
  ];
}
