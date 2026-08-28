{ pkgs, ... }:

let
  # Dolphin (Qt 6.11) crashes with a Wayland protocol error under Hyprland 0.55. Wrapping the
  # binary rather than a .desktop covers the SUPER+E bind and xdg-open too, since both resolve
  # `dolphin` off PATH. Harmless here as both monitors are 1080p @ scale 1; drop once Qt or
  # Hyprland ships a fix.
  dolphin-xcb = pkgs.symlinkJoin {
    name = "dolphin-xcb";
    paths = [ pkgs.kdePackages.dolphin ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/dolphin --set QT_QPA_PLATFORM xcb
    '';
  };
in
{
  # Ark's cli7z/clirar plugins need these on PATH for password-protected archives; libarchive
  # alone won't apply a password.
  home.packages = with pkgs; [
    dolphin-xcb
    kdePackages.ark
    kdePackages.kio-extras
    p7zip
    unrar
  ];
}
