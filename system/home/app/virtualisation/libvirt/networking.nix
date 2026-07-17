{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # eth0 is a br0 bridge port, so it must not run DHCP or be NetworkManager-managed, else NM pulls it out of br0 and the bridge loses its uplink.
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
