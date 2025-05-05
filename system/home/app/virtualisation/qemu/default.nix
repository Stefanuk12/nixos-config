{ config, pkgs, ... }:

{
  imports = [
    ./pkg.nix
    ./hooks.nix
  ];
}