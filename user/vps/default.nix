{ config, nixpkgs, pkgs, ... }:

{
  imports = [
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [];
}
