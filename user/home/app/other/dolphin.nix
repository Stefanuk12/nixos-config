{ pkgs, ... }:

{
  # Ark's cli7z/clirar plugins need these on PATH for password-protected archives; libarchive
  # alone won't apply a password.
  home.packages = with pkgs; [
    kdePackages.ark
    p7zip
    unrar
  ];

  # Dolphin (Qt 6.11) crashes with a Wayland protocol error under Hyprland 0.55. Harmless to force
  # onto XWayland here since both monitors are 1080p @ scale 1.
  xdg.desktopEntries."org.kde.dolphin" = {
    name = "Dolphin";
    genericName = "File Manager";
    exec = "env QT_QPA_PLATFORM=xcb dolphin %u";
    icon = "system-file-manager";
    categories = [ "Qt" "KDE" "System" "FileManager" "Utility" ];
    mimeType = [ "inode/directory" ];
    terminal = false;
  };
}
