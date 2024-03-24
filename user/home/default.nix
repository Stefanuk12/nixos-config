{ config, ... }:

{
  imports = [
    ./wm
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];
}
