# Build a static-site root from a directory (minus its default.nix) and symlink it into
# /var/www/<name> via tmpfiles.
{ pkgs, name, dir }:

let
  src = builtins.filterSource (path: _type: builtins.baseNameOf path != "default.nix") dir;
  root = pkgs.runCommand "${name}-root" { } ''
    mkdir -p "$out"
    cp -r ${src}/. "$out/"
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/www 0755 nginx nginx - -"
    "L+ /var/www/${name} - - - - ${root}"
  ];
}
