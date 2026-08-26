{ ... }:

{
  boot.kernelModules = [ "thunderbolt-net" ];

  services.hardware.bolt.enable = true;

  # Point-to-point link to the laptop: no DHCP on it, so both ends are static.
  networking.interfaces.thunderbolt0.ipv4.addresses = [
    {
      address = "10.10.10.1";
      prefixLength = 24;
    }
  ];

  # Same reason as eno1: NetworkManager would autoconnect a wired profile, chase the DHCP server
  # that isn't there and drop the static address on the way.
  networking.networkmanager.unmanaged = [ "thunderbolt0" ];
}
