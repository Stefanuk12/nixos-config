{ lib, config, ... }:

{
  # Load Cloudflare API credentials
  sops.secrets."cf_api_token" = {
    sopsFile = ../../../secrets/vps/cloudflare.yaml;
    owner = "acme";
  };
  sops.templates."acme-env" = {
    owner = "acme";
    group = "acme";
    mode = "0400";
    content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.cf_api_token}
    '';
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
      webroot = null;
      environmentFile = config.sops.templates."acme-env".path;
      extraDomainNames = [ "*.petrovic.foo" ];
    };
  };
}
