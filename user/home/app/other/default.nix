{ pkgs, ... }:

{
  imports = [
    ./claude_desktop.nix
    ./nixfmt.nix
    ./spotify.nix
  ];
}
