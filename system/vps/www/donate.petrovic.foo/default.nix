{ pkgs, ... }:

let
  src = builtins.filterSource (path: type: builtins.baseNameOf path != "default.nix") ./.;
  donateRoot = pkgs.runCommand "donate.petrovic.foo-root" {} ''
    mkdir -p "$out"
    cp -r ${src}/. "$out/"
  '';
in {
  systemd.tmpfiles.rules = [
    "d /var/www 0755 nginx nginx - -"
    "L /var/www/donate.petrovic.foo - - - - ${donateRoot}"
  ];
}