{ config, nixpkgs, ... }:

{
  imports = [
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  nixpkgs.config.allowUnfree = true;
}
