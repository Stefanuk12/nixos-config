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
}
