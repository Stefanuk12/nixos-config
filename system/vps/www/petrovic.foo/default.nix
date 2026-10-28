# petrovic.foo: the Leptos server from github:Stefanuk12/petrovic_foo, proxied to by nginx.
#
# The site isn't built here. Its CI builds it, signs the closure, `nix copy`s it in as `deploy`
# and points the profile below at it, so a site update needs no system rebuild. `deploy` isn't a
# trusted Nix user; the store only accepts its paths because they carry the CI's signature.
{ pkgs, ... }:

let
  profile = "/nix/var/nix/profiles/per-user/deploy/petrovic-foo";
  cacheDir = "/var/cache/petrovic-foo";
in
{
  users.users.deploy = {
    isSystemUser = true;
    group = "deploy";
    shell = pkgs.bashInteractive;
    home = "/var/lib/deploy";
    createHome = true;
    openssh.authorizedKeys.keys = [
      "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhKFVKytGMiMkTyTf6goty4UDH4WEvYIeHyY7+rxW3/ petrovic_foo CI deploy"
    ];
  };
  users.groups.deploy = { };

  nix.settings.extra-trusted-public-keys = [
    "petrovic-foo-ci-1:INZe4XmxbgWsF0qPWK1MZZpJW1Yl6AFBb2ncCv30CsQ="
  ];

  # Under /nix/var/nix/profiles so the deployed build is a GC root.
  systemd.tmpfiles.rules = [ "d /nix/var/nix/profiles/per-user/deploy 0755 deploy deploy - -" ];

  security.sudo.extraRules = [
    {
      users = [ "deploy" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl restart petrovic-foo.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.services.petrovic-foo = {
    description = "petrovic.foo";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    # Skipped until the first deploy creates the profile.
    unitConfig.ConditionPathExists = profile;

    environment = {
      LEPTOS_SITE_ADDR = "127.0.0.1:3000";
      RESUME_CACHE_DIR = cacheDir;
      # latexmk writes its font caches under $HOME.
      HOME = cacheDir;
    };

    serviceConfig = {
      ExecStart = "${profile}/bin/petrovic_foo";
      Restart = "on-failure";
      DynamicUser = true;
      CacheDirectory = "petrovic-foo";

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };
}
