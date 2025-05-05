{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wayland
    waydroid
  ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    enableHidpi = true;
  };
  services.xserver = {
    enable = true;
    xkb = {
      layout = "us";
      variant = "";
      options = "caps:escape";
    };
  };
}
