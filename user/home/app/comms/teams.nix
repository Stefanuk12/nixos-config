{ pkgs, ... }:

{
  home.packages = [ pkgs.teams-for-linux ];

  xdg.mimeApps.defaultApplications."x-scheme-handler/msteams" = "teams-for-linux.desktop";
}
