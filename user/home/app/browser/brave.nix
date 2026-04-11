{ pkgs, ... }:

{
  programs.chromium = {
    enable = true;
    package = pkgs.brave;
    # defaultSearchProviderEnabled = true;
    # defaultSearchProviderSearchURL = "https://duckduckgo.com/?q=search={searchTerms}";
  };
  programs.chromium.extensions = [
    "nngceckbapebfimnlniiiahkandclblb" # bitwarden
  ];

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "text/html" = "brave-browser.desktop";
    "x-scheme-handler/http" = "brave-browser.desktop";
    "x-scheme-handler/https" = "brave-browser.desktop";
  };
}
