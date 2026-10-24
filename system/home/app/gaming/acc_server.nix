{ ... }:

{
  # 8999/udp is ACC's LAN discovery broadcast.
  networking.firewall.interfaces.br0 = {
    allowedTCPPorts = [ 9232 ];
    allowedUDPPorts = [ 9231 8999 ];
  };
}
