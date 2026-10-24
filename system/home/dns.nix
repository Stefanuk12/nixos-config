{ lib, ... }:

{
  # Pi-hole on the Pi is the only resolver that knows the home-*.petrovic.foo hosts. The
  # router's DHCP resolver must not sit next to it: Tailscale forwards to it and gets the
  # public Cloudflare answer. br0's DHCP is dhcpcd, not NM, so both need muting. resolved
  # would otherwise have NM push the router's resolver into it, hence the mkForce.
  networking.nameservers = [ "192.168.0.10" ];
  networking.networkmanager.dns = lib.mkForce "none";
  networking.dhcpcd.extraConfig = "nohook resolv.conf";

  # Local cache: without one, Steam CDN bursts trip Pi-hole's per-client rate limit and the
  # REFUSED-retry storm takes DNS down host-wide for minutes.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "false";
      LLMNR = "false";
    };
  };
}
