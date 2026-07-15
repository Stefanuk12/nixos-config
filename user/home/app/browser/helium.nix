{ inputs, pkgs, ... }:

{
  imports = [ inputs.helium.homeModules.default ];

  programs.helium = {
    enable = true;
    # Use the overlay package so this and the exec-once launcher share one store path.
    package = pkgs.helium;
    # No `policies` here, and don't add ExtensionInstallForcelist system-side
    # either: helium reads /etc/chromium/policies (NOT the user-level file this
    # module writes -- wrong dir anyway, the browser lives in
    # ~/.config/net.imput.helium), but its ungoogled download path never
    # completes forced installs. The forcelisted IDs just become policy-managed,
    # which BLOCKS installing those extensions manually ("blocked by
    # administrator"). Install extensions once from the web store instead.
  };

  # helium.desktop only exists in ~/.nix-profile/share, which apps running with
  # a minimal XDG_DATA_DIRS can't see -- their link-opening then finds "no app"
  # (or, worse, falls back to whatever mimeinfo.cache offers). ~/.local/share is
  # always searched, so mirror the desktop file there.
  # force: helium itself rewrites this file at runtime (e.g. when registering
  # as default browser), which would otherwise abort later switches with a
  # would-be-clobbered error.
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
