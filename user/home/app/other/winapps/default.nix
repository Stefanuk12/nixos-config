{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps
    # inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps-launcher
    pkgs.freerdp
  ];

  home.file.".config/winapps/winapps.conf".source = ./winapps.conf;
}
