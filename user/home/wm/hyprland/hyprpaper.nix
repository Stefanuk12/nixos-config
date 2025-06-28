{ pkgs, ... }:

let
  wallpaper = pkgs.fetchurl {
    url = "https://github.com/woioeow/hyprland-dotfiles/blob/main/hypr_style1/wallpaper/astronaut.png?raw=true";
    hash = "sha256-90AKuRRBoDKdBbjnDmf4vCj6CgOKavtCoVBRT8AIfac=";
  };
  misty_swimming_pool = {
    left = ../wallpapers/misty_swimming_pool/left.jpg;
    right = ../wallpapers/misty_swimming_pool/right.jpg;
  };
in {
  services.hyprpaper.enable = true;

  # https://wiki.hypr.land/Hypr-Ecosystem/hyprpaper/
  services.hyprpaper.settings = {
    preload = [
      "${wallpaper}"
      "${misty_swimming_pool.left}"
      "${misty_swimming_pool.right}"
    ];
    wallpaper = [
      "HDMI-A-1, ${misty_swimming_pool.left}"
      "DP-1, ${misty_swimming_pool.right}"
    ];
  };
}