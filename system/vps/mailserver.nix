{ config, pkgs, inputs, ... }:

{
  imports = [
    (builtins.fetchTarball {
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/nixos-24.11/nixos-mailserver-nixos-24.11.tar.gz";
      # To get the sha256 of the nixos-mailserver tarball, we can use the nix-prefetch-url command:
      # release="nixos-24.11"; nix-prefetch-url "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz" --unpack
      sha256 = "05k4nj2cqz1c5zgqa0c6b8sp3807ps385qca74fgs6cdc415y3qw";
    })
  ];

  # Load the secrets in
  sops.secrets.key-mail = {
    sopsFile = ../../secrets/vps/ssl.yaml;
    owner = config.users.users.stefan.name;
    key = "petrovic.foo/key";
  };
  sops.secrets.cert-mail = {
    sopsFile = ../../secrets/vps/ssl.yaml;
    owner = config.users.users.stefan.name;
    key = "petrovic.foo/cert";
  };
  sops.secrets.email_password = {
    sopsFile = ../../secrets/common/stefan.yaml;
    owner = config.users.users.stefan.name;
  };
  sops.secrets.cf_email = {
    sopsFile = ../../secrets/vps/cloudflare.yaml;
    owner = "cf_secrets";
    key = "petrovic.foo/email";
  };
  sops.secrets.cf_api_key = {
    sopsFile = ../../secrets/vps/cloudflare.yaml;
    owner = "cf_secrets";
    key = "petrovic.foo/api_key";
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

  # Start the mailserver
  services.dovecot2.sieve.extensions = [ "fileinto" ];
  services.postfix.config.smtp_helo_name = "mail.petrovic.foo";
  services.postfix.headerChecks = [
    "/^Content-Type:/i PREPEND List-Unsubscribe: mailto:stefan@petrovic.foo?subject=unsubscribe"
  ];
  mailserver = {
    enable = true;
    enablePop3 = true;
    enablePop3Ssl = true;
  
    fqdn = "mail.petrovic.foo";
    sendingFqdn = "mail.petrovic.foo";
    domains = [ "petrovic.foo" ];

    # A list of all login accounts. To create the password hashes, use
    # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
    loginAccounts = {
      "stefan@petrovic.foo" = {
        hashedPasswordFile = config.sops.secrets.email_password.path;
        aliases = ["postmaster@petrovic.foo"];
        aliasesRegexp = ["stefan(\+\w+)?@petrovic\.foo"];
      };
    };

    certificateScheme = "acme-nginx";
  };
  
  security.acme = {
    acceptTerms = true;
    defaults.email = "security@petrovic.foo";
    certs."petrovic.foo" = {
      # domain = "*.petrovic.foo";
      dnsProvider = "cloudflare";
      environmentFile = "/var/lib/cf_secrets/secret";
    };
  };
}
