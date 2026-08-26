{ hostName, ... }:

let
  # wsdd needs both 3702 (probes) and 5357 (metadata), or the host resolves by name but never
  # appears in Explorer.
  sharePorts = {
    allowedTCPPorts = [
      445
      5357
    ];
    allowedUDPPorts = [ 3702 ];
  };
in
{
  services.samba = {
    enable = true;
    # Windows has shipped with SMB1 and Computer Browser off since 10 1709, so nmbd would only
    # ever answer itself; wsdd replaces it.
    nmbd.enable = false;

    settings = {
      global = {
        "server string" = "Linux PC";
        "workgroup" = "WORKGROUP";
        # Every supported Windows speaks 3.1.1, so the floor costs nothing and buys AES-GCM signing.
        "server min protocol" = "SMB3_11";
        "hosts allow" = "192.168.0.0/24 10.10.10.0/24 127.0.0.1";
        "hosts deny" = "0.0.0.0/0";
        "map to guest" = "never";
      };

      Public = {
        path = "/home/stefan/Public";
        "valid users" = "stefan";
        writable = "yes";
        browseable = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    interface = "br0";
    hostname = hostName;
    workgroup = "WORKGROUP";
    openFirewall = false;
  };

  # Per-interface rather than the modules' openFirewall, which would also open 445 on both libvirt
  # bridges, pia-br and every container veth.
  networking.firewall.interfaces.br0 = sharePorts;
  networking.firewall.interfaces.thunderbolt0 = sharePorts;
}
