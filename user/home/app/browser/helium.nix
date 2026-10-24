{ inputs, pkgs, ... }:

{
  imports = [ inputs.helium.homeModules.default ];

  programs.helium = {
    enable = true;
    # Overlay package, so this and the exec-once launcher share one store path.
    package = pkgs.helium;
    # No `policies` / ExtensionInstallForcelist: helium's ungoogled download path never completes
    # forced installs, and forcelisting an ID blocks installing it manually. Use the web store.
    # Exception: auto-translate is unpacked from the store via --load-extension, set on the
    # overlay package in flake.nix so every launch path picks it up.
    #
    # Repeated here because the module builds home.packages as `package.override { flags = cfg.flags; }`,
    # so leaving this empty overrides the overlay's flags back off and only `helium` on PATH loses the
    # extension. Same value as the overlay means the override is a no-op and the store path stays shared;
    # keep the two in sync.
    flags = [ "--load-extension=${pkgs.helium-autotranslate}" ];
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
