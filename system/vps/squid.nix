{ config, pkgs, inputs, ... }:

{
  imports = [
    (builtins.fetchTarball {
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/nixos-23.05/nixos-mailserver-nixos-23.05.tar.gz";
      # To get the sha256 of the nixos-mailserver tarball, we can use the nix-prefetch-url command:
      # release="nixos-23.05"; nix-prefetch-url "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz" --unpack
      sha256 = "1ngil2shzkf61qxiqw11awyl81cr7ks2kv3r3k243zz7v2xakm5c";
    })
  ];

  # Load the secrets in
  sops.secrets.home_ip = {
    sopsFile = ../../secrets/vps/squid.yaml;
    owner = config.users.users.stefan.name;
  };

  # Building the CF secrets
  systemd.services."cf_secrets" = {
    requiredBy = [ "acme-petrovic.foo.service" ];
    before = [ "acme-petrovic.foo.service" ];
    serviceConfig = {
      Type = "oneshot";
      UMask = 0077;
    };
    script = ''
      echo "
      CLOUDFLARE_DNS_API_TOKEN=$(cat ${config.sops.secrets.cf_api_key.path})
      CLOUDFLARE_ZONE_API_TOKEN=$(cat ${config.sops.secrets.cf_api_key.path})
      " > /var/lib/cf_secrets/secret
    '';
    serviceConfig = {
      User = "cf_secrets";
      WorkingDirectory = "/var/lib/cf_secrets";
    };
  };
  users.users."cf_secrets" = {
    home = "/var/lib/cf_secrets";
    createHome = true;
    isSystemUser = true;
    group = "cf_secrets";
  };
  users.groups."cf_secrets" = { };

  # Start Squid
  nixpkgs.config.permittedInsecurePackages = [
    "squid-6.12"
  ];
  services.squid = {
    enable = true;
    extraConfig = "
      acl localnet src 192.168.0.1
      http_access allow authenticated
    ";
  };
}
