{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pia-confinement.nixosModules.default
  ];

  # VPN-Confinement's global-scope IPv6 ULA on pia-br makes glibc/Chromium prefer v6 on this v6-less box and black-hole connections (Spotify "offline"), so drop it once the namespace is up; apps stay reachable over the IPv4 bridge.
  systemd.services.pia.serviceConfig.ExecStartPost =
    "${pkgs.iproute2}/bin/ip -6 addr flush dev pia-br scope global";

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
