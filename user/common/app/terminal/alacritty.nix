{ pkgs, lib, ... }:

{
  home.packages = with pkgs.userPkgs; [
    alacritty
  ];

  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = lib.mkForce 0.75;
    };
  };
}
