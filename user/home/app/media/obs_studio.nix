{ pkgs, ... }:

{
  programs.obs-studio.enable = true;
  programs.obs-studio.plugins = with pkgs.obs-studio-plugins; [
    wlrobs
    obs-backgroundremoval
    obs-pipewire-audio-capture
    obs-vaapi
    obs-gstreamer
    obs-vkcapture
    looking-glass-obs
  ];
}