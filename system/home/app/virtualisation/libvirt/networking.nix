{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # eth0 is a bridge port: it must not run DHCP itself, and NetworkManager
  # must not manage it — its ethernet profile would pull eth0 out of br0,
  # leaving the bridge with no uplink (VMs then get no DHCP/IP).
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
