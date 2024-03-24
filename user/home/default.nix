{ config, nixpkgs, ... }:

{
  imports = [
    ./wm
    ./app/comms/discord.nix
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  nixpkgs.config.allowUnfree = true;
}
