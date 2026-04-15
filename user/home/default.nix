{
  inputs,
  config,
  nixpkgs,
  ...
}:

{
  imports = [
    inputs.nix-colors.homeManagerModules.default

    ./wm
    ./app
    ../common/app/sops.nix
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.ayu-dark;

  nixpkgs.config.allowUnfree = true;
}
