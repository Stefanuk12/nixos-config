{ inputs, ... }:

{
  imports = [ inputs.psvr2-toolkit.nixosModules.default ];

  hardware.psvr2.enable = true;
}
