{ pkgs, ... }:

{
  home.packages = with pkgs.userPkgs; [
    termius
  ];
}
