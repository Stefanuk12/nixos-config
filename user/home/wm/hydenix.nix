{ inputs, pkgs, ... }:

{
  imports = [
    inputs.hydenix.homeModules.default
  ];  

  home.packages = with pkgs; [
    networkmanagerapplet
  ];

  hydenix.hm = {
    enable = true;
    # shell.enable = false;
    hyde.enable = true;
    editors.enable = false;
    firefox.enable = false;
    git.enable = false;
    social.enable = false;
    rofi.enable = true;
    waybar.enable = true;
  };

  hydenix.hm.hyprland = {
    enable = true;
    nvidia.enable = false;
    extraConfig = ''
      exec-once = kdeconnect-indicator
      env = AQ_DRM_DEVICES,/dev/dri/amd-igpu

      input {
        kb_layout = "iso_us"
        kb_variant = "intl"
        accel_profile = "flat"
        sensitivity = -0.8
      }
    '';
    keybindings.extraConfig = ''
      bind = SUPER, I, exec, pgrep -x bwm || bwm"
    '';
    monitors.overrideConfig = ''
      # monitor = HDMI-A-2, 1920x1080@165, 3840x0, 1
      monitor = HDMI-A-2, 1920x1080@75, 0x0, 1, vrr, 1
      monitor = DP-4, 1920x1080@165, 1920x0, 1, vrr, 1, bitdepth, 10
    '';
  };
}
