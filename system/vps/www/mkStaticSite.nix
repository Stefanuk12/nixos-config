# Build a static-site root from a directory (excluding this repo's default.nix)
# and symlink it into /var/www/<name> via tmpfiles. Shared by the per-site
# modules so the runCommand + tmpfiles boilerplate isn't copy-pasted per host.
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
