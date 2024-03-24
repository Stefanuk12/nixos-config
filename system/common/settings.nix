{ lib, ... }:
let
  mkOption = lib.mkOption;
  types = lib.types;
in {
  options.systemSettings = {
    username = mkOption {
      type = types.str;
      default = "stefan";
      description = ''
        A username.
      '';
    };

    stateVersion = mkOption {
      type = types.str;
      default = "23.05";
      description = ''
        The version of NixOS to use.
      '';
    };
  };
}
