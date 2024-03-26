{ lib, ... }:
let
  mkOption = lib.mkOption;
  types = lib.types;
in {
  options.systemSettings = {
    stateVersion = mkOption {
      type = types.str;
      default = "23.05";
      description = ''
        The version of NixOS to use.
      '';
    };
  };
}
