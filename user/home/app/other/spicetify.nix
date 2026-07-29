{ inputs, pkgs, ... }:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.default ];

  # Patches Spotify at build time rather than running `spicetify apply` against the store, which
  # is read-only. spotifyPackage defaults to pkgs.spotify, so this themes the pinned snap build
  # from homeOverlays; the plain spotify package is dropped from systemPackages to avoid two
  # copies on PATH.
  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.comfy;
    colorScheme = "catppuccin-mocha";
  };
}
