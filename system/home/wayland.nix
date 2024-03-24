{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wayland
    waydroid
  ];

  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
      options = "caps:escape";
    };
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      enableHidpi = true;
      #theme = "chili";
    };
  };
}
