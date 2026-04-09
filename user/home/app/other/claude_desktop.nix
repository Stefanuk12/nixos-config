{ pkgs, inputs, ... }:

{
  home.packages = with pkgs.userPkgs; [
    inputs.claude-desktop.packages.${pkgs.system}.claude-desktop-with-fhs
  ];
}
