{ ... }:

{
  services.tailscale.enable = true;

  # Sunshine and sshd are reachable over the tailnet without punching anything through the
  # router. Run `sudo tailscale up` once to enrol the host.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
