{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # eth0 is a br0 port: no DHCP, and unmanaged, else NM pulls it out and the bridge loses uplink.
  networking.interfaces.eth0.useDHCP = false;
  networking.networkmanager.unmanaged = [ "eth0" ];
  networking.interfaces.br0.useDHCP = true;
  networking.bridges = {
    "br0" = {
      interfaces = [ "eth0" ];
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
