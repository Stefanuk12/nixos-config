{ pkgs, ... }:

{
  home.packages = with pkgs; [
    boxflat
  ];
}
