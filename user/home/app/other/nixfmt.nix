{ pkgs, ... }:

{
  home.packages = with pkgs.userPkgs; [
    nixfmt
  ];
}
