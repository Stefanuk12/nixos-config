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
  services.nginx.virtualHosts = {
    default = {
      serverName = "_";
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
    };
    "petrovic.foo" = {
      root = "/var/www/petrovic.foo";
      forceSSL = true;
      enableACME = true;
    };
    "crypto.petrovic.foo" = {
      root = "/var/www/crypto.petrovic.foo";
    }
  };

  security.acme.certs."petrovic.foo".webroot = null;
}
