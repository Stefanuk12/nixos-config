{ lib, config, ... }:

{
  # Load the secrets in
  sops.secrets."petrovic.foo/key" = {
    sopsFile = ../../../secrets/vps/ssl.yaml;
    owner = "nginx";
  };
  sops.secrets."petrovic.foo/cert" = {
    sopsFile = ../../../secrets/vps/ssl.yaml;
    owner = "nginx";
  };

  # NGINX setup
  services.nginx.enable = true;
  services.nginx.virtualHosts."petrovic.foo" = {
    root = "/var/www/petrovic.foo";
    forceSSL = true;
    enableACME = true;
  };

  security.acme.certs."petrovic.foo".webroot = null;
}
