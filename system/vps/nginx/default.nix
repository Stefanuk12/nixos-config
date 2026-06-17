{ lib, config, ... }:

let
  # Enforce that connections are genuinely proxied through *our* Cloudflare zone.
  #
  # Cloudflare per-hostname Authenticated Origin Pulls (mTLS): Cloudflare presents
  # our custom client certificate (./cf-aop-ca.pem, uploaded to the zone) on every
  # origin pull. The firewall already limits 80/443 to Cloudflare IPs, but those IPs
  # are shared by *all* tenants — including arbitrary Workers — so the cert is what
  # actually proves the traffic came through our zone and not someone else's.
  #
  # ssl_verify_client = on  -> reject any TLS connection without our client cert.
  # The Cf-Worker block is defence-in-depth: Cloudflare sets this header when a
  # Worker issues the subrequest, so we 403 those outright.
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
      enableACME = true;
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
