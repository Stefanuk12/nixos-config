{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:

{
  # eno1 (Intel I226-V) is the port with the cable. As a br0 port it gets no DHCP, and must be
  # unmanaged, else NM pulls it out and the bridge loses uplink.
  networking.interfaces.eno1.useDHCP = false;
  # On the port, not br0: ethtool's WoL flag lives on the physical device. Needs "Power On by
  # PCIe" in the BIOS, and ErP/Deep Sleep off, or the NIC loses standby power at S5.
  networking.interfaces.eno1.wakeOnLan.enable = true;
  networking.networkmanager.unmanaged = [
    "eno1"
    # Second onboard NIC (Realtek RTL8126), never cabled. Left managed, NM keeps autoconnecting a
    # default wired profile to a carrierless port. By MAC because its name is udev's to choose.
    "mac:a0:ad:9f:59:4f:18"
  ];
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
