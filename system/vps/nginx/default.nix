{ lib, config, ... }:

let
  # Cloudflare per-hostname Authenticated Origin Pull (mTLS): reject any origin-pull without our client cert (./cf-aop-ca.pem), since the CF-IP firewall allowlist is shared by all tenants; the Cf-Worker 403 is defence-in-depth.
  mtlsOriginPull = ''
    ssl_client_certificate ${./cf-aop-ca.pem};
    ssl_verify_client on;
    ssl_verify_depth 1;

    if ($http_cf_worker) {
      return 403;
    }
  '';
in
{
  # Load Cloudflare API credentials
  sops.secrets."api_token" = {
    sopsFile = ../../../secrets/vps/cloudflare.yaml;
    owner = "acme";
  };
  sops.templates."acme-env" = {
    owner = "acme";
    group = "acme";
    mode = "0400";
    content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder.api_token}
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
      extraConfig = mtlsOriginPull;
    };
    "donate.petrovic.foo" = {
      root = "/var/www/donate.petrovic.foo";
      forceSSL = true;
      useACMEHost = "petrovic.foo";
      extraConfig = mtlsOriginPull;
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
