{ ... }:

# The package itself is Home Manager's, via spicetify.nix — only the Spotify Connect discovery
# ports need root.
{
  networking.firewall.allowedTCPPorts = [ 57621 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];
}
