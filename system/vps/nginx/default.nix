{ lib, config, ... }:

{
  # Load Cloudflare API credentials
  sops.secrets."cloudflare/api_token" = {
    sopsFile = ../../../secrets/vps/cloudflare.yaml;
    owner = "acme";
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
    "donate.petrovic.foo" = {
      root = "/var/www/donate.petrovic.foo";
      forceSSL = true;
      enableACME = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "stefan@petrovic.foo";
    certs."petrovic.foo" = {
      dnsProvider = "cloudflare";
      environmentFile = config.sops.secrets."cloudflare/api_token".path;
      extraDomainNames = [ "*.petrovic.foo" ];
    };
  };
}
