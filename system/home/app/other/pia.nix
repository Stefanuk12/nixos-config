{ inputs, config, pkgs, ... }:

{
  imports = [
    inputs.pia-confinement.nixosModules.default
  ];

  # VPN-Confinement gives the host-side `pia-br` bridge a global-scope IPv6 ULA
  # (fd93:9701:1d00::1/64) so the host can reach confined apps over v6. But this
  # box has no IPv6 internet (no v6 default route), and that global-scope address
  # tricks glibc/Chromium into preferring IPv6 for dual-stack hosts — connections
  # to v6-only-resolved endpoints then black-hole (e.g. Spotify stuck "offline").
  # Drop the bridge's global v6 once the namespace is up; confined apps stay
  # reachable over the IPv4 bridge address (192.168.15.x).
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
