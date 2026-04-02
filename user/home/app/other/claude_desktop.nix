{ pkgs, ... }:

{
  home.packages = with pkgs; [
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
  ];
}