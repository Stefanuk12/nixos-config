{ config, nixpkgs, ... }:

{
  imports = [
    ./wm
    ./app/comms/discord.nix
    ./app/browser/brave.nix
    ./app/virtualisation
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  nixpkgs.config.allowUnfree = true;
}
