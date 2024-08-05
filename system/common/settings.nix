{ lib, ... }:
let
  mkOption = lib.mkOption;
  types = lib.types;
in {
  options.systemSettings = {
    sshKeys = mkOption {
      type = types.attrsOf(types.str);
      description = ''
        Everyone's SSH public keys. 
      '';
    };
  };

  config.systemSettings = {
    sshKeys = {
      "stefan@windows-pc" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQOdcA45T5jqnvhSiFy0/QihCMJiNAjOqgyxYuvYNcS stefan@windows-pc";
      "stefan@home" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEFi4KQP6TuvmqGZj52ZERC2cbBh4zbQ4BlHytSLmi5R stefan@home";
      "stefan@vps" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmnotNFy29WvH0oVL094zdNdHi1GydZZXpEnxgpFgMe stefan@vps";
    };
  };
}
