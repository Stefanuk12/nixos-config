{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./nixfmt.nix
    ./spotify.nix
    ./kde_connect.nix
  ];
}
