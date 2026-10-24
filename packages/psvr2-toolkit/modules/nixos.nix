{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.psvr2;
in
{
  options.hardware.psvr2 = {
    enable = lib.mkEnableOption "udev access rules for the PlayStation VR2 headset and Sense controllers";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/xr-hardware.nix { };
      defaultText = lib.literalExpression "xr-hardware 1.1.2";
      description = "xr-hardware package providing 70-xrhardware.rules.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ cfg.package ];
  };
}
