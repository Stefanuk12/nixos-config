{ inputs, ... }:

{
  imports = [
    inputs.hydenix.homeModules.default
  ];  

  hydenix.hm = {
    enable = true;
    hyde.enable = true;
    editors.enable = false;
    firefox.enable = false;
    git.enable = false;
    social.enable = false;
    rofi.enable = true;
  };

  hydenix.hm.hyprland = {
    enable = true;
    nvidia.enable = false;
    monitors.enable = false;
  };
}
