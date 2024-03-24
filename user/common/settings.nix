{ lib, ... }:
let
  mkOption = lib.mkOption;
  types = lib.types;
in {
  options.userSettings = {
    name = mkOption {
      type = types.str;
      default = "Stefan";
      description = ''
        A name to use for things like Git.
      '';
    };
    email = mkOption {
      type = types.str;
      default = "stefanukpadd@gmail.com";
      description = ''
        An email to use for things like Git.
      '';
    };
    terminal = mkOption {
      type = types.str;
      default = "alacritty";
      description = ''
        The terminal to use.
      '';
    };
  };
}
