{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # eno1 is the port with the cable (eth0 is the second, unused onboard NIC). As a br0 port it gets
  # no DHCP, and must be unmanaged, else NM pulls it out and the bridge loses uplink.
  networking.interfaces.eno1.useDHCP = false;
  networking.networkmanager.unmanaged = [ "eno1" ];
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = [ "eno1" ];
    };
  };

  virtualisation.libvirtd.allowedBridges = [
    "nm-bridge"
    "virbr0"
    "br0"
  ];

  networking.firewall.interfaces.br0 = {
    allowedTCPPorts = [ 33882 ];
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
  };
}
