{ pkgs, ... }:

{
  # The daemon + udev rules live system-side in system/home/app/other/trezor.nix. trezorctl is
  # left out: it needs py-evm, which upstream marks unsupported on python3.14, so it won't build.
  home.packages = [ pkgs.trezor-suite ];
}
