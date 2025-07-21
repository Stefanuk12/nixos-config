{ ... }: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "instance-20250719-1457";
  networking.domain = "subnet07190031.vcn07190031.oraclevcn.com";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQOdcA45T5jqnvhSiFy0/QihCMJiNAjOqgyxYuvYNcS stefan@windows-pc'' ];
  system.stateVersion = "23.11";
}