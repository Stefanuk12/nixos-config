{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  networking.interfaces.eth0.useDHCP = true;
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
    allowedTCPPortRanges = [{ from = 1714; to = 1764; }];
    allowedUDPPortRanges = [{ from = 1714; to = 1764; }];
  };
}