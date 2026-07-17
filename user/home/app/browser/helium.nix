{ inputs, pkgs, ... }:

{
  imports = [ inputs.helium.homeModules.default ];

  programs.helium = {
    enable = true;
    # Use the overlay package so this and the exec-once launcher share one store path.
    package = pkgs.helium;
    # No `policies` / ExtensionInstallForcelist: helium's ungoogled download path never completes forced installs and forcelisted IDs just become policy-managed, blocking manual installs — install extensions from the web store instead.
  };

  # Mirror helium.desktop into ~/.local/share (always searched, unlike ~/.nix-profile/share) with force=true, since helium rewrites it at runtime when registering as default browser.
  xdg.dataFile."applications/helium.desktop" = {
    source = "${pkgs.helium}/share/applications/helium.desktop";
    force = true;
  };

  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "text/html" = "helium.desktop";
    "x-scheme-handler/http" = "helium.desktop";
    "x-scheme-handler/https" = "helium.desktop";
  };
}
