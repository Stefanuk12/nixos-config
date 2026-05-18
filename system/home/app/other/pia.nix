{ inputs, config, ... }:

{
  imports = [
    inputs.pia-confinement.nixosModules.default
  ];

  rbw-fetch.secrets.pia-creds.script = ''
    pia_user=$(rbw get --field username PrivateInternetAccess)
    pia_pass=$(rbw get PrivateInternetAccess)
    printf '%s\n%s\n' "$pia_user" "$pia_pass" > "$OUT"
  '';

  systemd.services.pia-wg-gen = {
    requires = [ config.rbw-fetch.secrets.pia-creds.serviceName ];
    after = [ config.rbw-fetch.secrets.pia-creds.serviceName ];
  };

  services.pia-confinement = {
    enable = true;
    region = null;
    credentialsFile = config.rbw-fetch.secrets.pia-creds.path;

    confinedApps.qbittorrent = {
      enable = true;
      user = "stefan";
    };
  };
}
