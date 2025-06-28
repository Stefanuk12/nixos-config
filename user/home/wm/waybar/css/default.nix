{ pkgs, ... } @ inputs:

let
  theme = import ./theme.nix inputs;
in {
  file = pkgs.writeText "style.css"
  ''
  @import "${theme.file}";
  '';
}