{ pkgs, inputs, ... }:

{
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/claude" = "claude-desktop-opener.desktop";
  };
  xdg.desktopEntries.claude-desktop-opener = {
    name = "Claude Desktop";
    exec = "claude-desktop %u";
    type = "Application";
    mimeType = [ "x-scheme-handler/claude" ];
    noDisplay = true;
  };

  home.packages = with pkgs; [
    claude-desktop-fhs
  ];
}
