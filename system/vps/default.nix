{ ... }:

{
  imports = [
    ./nginx
    ./minecraft
    ./mailserver.nix
    ./firewall.nix
  ];
}
