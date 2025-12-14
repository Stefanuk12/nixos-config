{ config, pkgs, ... }:

{
  imports = [
    ./pkg.nix
    ./kvmfr.nix
  ];
}