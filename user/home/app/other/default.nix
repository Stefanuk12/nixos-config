{ pkgs, ... }:

{
  imports = [
    ./spotify.nix
    ./claude_desktop.nix
  ];
}