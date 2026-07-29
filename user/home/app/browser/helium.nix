{ inputs, pkgs, ... }:

{
  imports = [ inputs.helium.homeModules.default ];

  programs.helium = {
    enable = true;
    # Overlay package, so this and the exec-once launcher share one store path.
    package = pkgs.helium;
    # No `policies` / ExtensionInstallForcelist: helium's ungoogled download path never completes
    # forced installs, and forcelisting an ID blocks installing it manually. Use the web store.
  };

  # ~/.local/share is always searched, unlike ~/.nix-profile/share; force=true because helium
  # rewrites the file at runtime when registering as default browser.
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
