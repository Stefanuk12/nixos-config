{ config, pkgs, ... }:

let
  cloudflareIPv4 = [
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
  ];
  cloudflareIPv6 = [
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
  ];

  ipv4Commands = builtins.concatStringsSep "\n"
    (map (ip: ''
      iptables -A INPUT -p tcp -m multiport --dports 80,443 -s ${ip} -j ACCEPT
    '') cloudflareIPv4);

  ipv6Commands = builtins.concatStringsSep "\n"
    (map (ip: ''
      ip6tables -A INPUT -p tcp -m multiport --dports 80,443 -s ${ip} -j ACCEPT
    '') cloudflareIPv6);
in {
  # Fail2Ban (basic SSH protection)
  services.fail2ban.enable = true;

  # Allow SSH openly but only Cloudflare IPs on HTTP(S)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    allowedUDPPorts = [ ];

    extraCommands = ''
      ${ipv4Commands}
      ${ipv6Commands}
    '';
  };
}