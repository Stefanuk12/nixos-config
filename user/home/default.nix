{ inputs, config, nixpkgs, ... }:

{
  imports = [
    inputs.nix-colors.homeManagerModules.default

    ./wm
    ./app/dev/vscode.nix
    ./app/comms/discord.nix
    ./app/browser/brave.nix
    ./app/security/bitwarden.nix
    ./app/utils/nixvim
    ./app/virtualisation
    ../common/app/shell/sh.nix
    ../common/app/git.nix
  ];

  colorScheme = inputs.nix-colors.colorSchemes.ayu-dark;

  nixpkgs.config.allowUnfree = true;
}
