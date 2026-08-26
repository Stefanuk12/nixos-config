{ lib, ... }:
let
  mkOption = lib.mkOption;
  types = lib.types;
in
{
  options.userSettings = {
    name = mkOption {
      type = types.str;
      default = "Stefan Petrovic";
      description = ''
        A name to use for things like Git.
      '';
    };
    email = mkOption {
      type = types.str;
      default = "stefan@petrovic.foo";
      description = ''
        An email to use for things like Git.
      '';
    };
    terminal = mkOption {
      type = types.str;
      default = "ghostty";
      description = ''
        The terminal to use.
      '';
    };
    ghUsername = mkOption {
      type = types.str;
      default = "Stefanuk12";
      description = ''
        Your GitHub username.
      '';
    };
    mainMonitor = mkOption {
      type = types.str;
      default = "DP-1";
      description = ''
        Connector name of the primary output. Shell surfaces that should live on exactly one
        monitor (bar, dock, OSD, notifications) are anchored here.
      '';
    };
  };
}
