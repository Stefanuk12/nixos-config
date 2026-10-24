{ pkgs, ... }:

{
  home.packages = [
    # It's already running inside the nixpkgs FHS/bwrap sandbox; the check just doesn't detect it.
    (pkgs.bottles.override { removeWarningPopup = true; })
  ];
}
