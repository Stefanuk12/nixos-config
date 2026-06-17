{ pkgs, ... }:

{
  # Dolphin extracts/creates archives through Ark, which shells out to CLI
  # backends for the actual work. Without these on PATH, Ark's cli7z/clirar
  # plugins are unavailable, so password-protected archives can't be opened or
  # created (libarchive alone won't prompt for / apply a password):
  #   p7zip -> 7z: encrypted ZIP (AES) and 7z archives
  #   unrar      : password-protected RAR archives
  # ark itself ships the Dolphin context-menu integration and the plugins.
  home.packages = with pkgs; [
    kdePackages.ark
    p7zip
    unrar
  ];

  # Dolphin (Qt 6.11) crashes with a fatal Wayland protocol error
  # ("wl_display error 0: invalid object", exit 255) when interacting with it
  # under Hyprland 0.55. Forcing it onto XWayland (QT_QPA_PLATFORM=xcb) avoids
  # the bad selection/clipboard protocol path. Override only Dolphin's launcher
  # so every other Qt app keeps running native Wayland.
  # Both monitors are 1080p @ scale 1, so XWayland has no scaling downside here.
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
