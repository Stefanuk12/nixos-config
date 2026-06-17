{ pkgs, ... }:

{
  # Ark (Dolphin's archive integration) needs these CLI backends on PATH for its
  # cli7z/clirar plugins, else password-protected 7z/ZIP/RAR archives can't be
  # opened or created (libarchive alone won't apply a password).
  home.packages = with pkgs; [
    kdePackages.ark
    p7zip
    unrar
  ];

  # Dolphin (Qt 6.11) crashes with a fatal Wayland protocol error under Hyprland
  # 0.55; force it onto XWayland (QT_QPA_PLATFORM=xcb) to avoid the bad
  # selection/clipboard path. Override only Dolphin so other Qt apps stay native;
  # both monitors are 1080p @ scale 1, so XWayland has no scaling downside.
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
