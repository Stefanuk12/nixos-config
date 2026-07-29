{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.winapps.packages.${pkgs.stdenv.hostPlatform.system}.winapps
    pkgs.freerdp
  ];

  home.file.".config/winapps/winapps.conf".source = ./winapps.conf;
}
