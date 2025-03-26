{ config, pkgs, ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];

    extraConfig = ''
      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]

      # Allow established connections
      -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

      # Cloudflare IPv4
      -A INPUT -s 103.21.244.0/22 -j ACCEPT
      -A INPUT -s 103.22.200.0/22 -j ACCEPT
      -A INPUT -s 103.31.4.0/22 -j ACCEPT
      -A INPUT -s 104.16.0.0/13 -j ACCEPT
      -A INPUT -s 104.24.0.0/14 -j ACCEPT
      -A INPUT -s 108.162.192.0/18 -j ACCEPT
      -A INPUT -s 131.0.72.0/22 -j ACCEPT
      -A INPUT -s 141.101.64.0/18 -j ACCEPT
      -A INPUT -s 162.158.0.0/15 -j ACCEPT
      -A INPUT -s 172.64.0.0/13 -j ACCEPT
      -A INPUT -s 173.245.48.0/20 -j ACCEPT
      -A INPUT -s 188.114.96.0/20 -j ACCEPT
      -A INPUT -s 190.93.240.0/20 -j ACCEPT
      -A INPUT -s 197.234.240.0/22 -j ACCEPT
      -A INPUT -s 198.41.128.0/17 -j ACCEPT

      # Cloudflare IPv6
      -A INPUT -s 2400:cb00::/32 -j ACCEPT
      -A INPUT -s 2606:4700::/32 -j ACCEPT
      -A INPUT -s 2803:f800::/32 -j ACCEPT
      -A INPUT -s 2405:b500::/32 -j ACCEPT
      -A INPUT -s 2405:8100::/32 -j ACCEPT
      -A INPUT -s 2a06:98c0::/29 -j ACCEPT
      -A INPUT -s 2c0f:f248::/32 -j ACCEPT

      COMMIT
    '';
  };
}