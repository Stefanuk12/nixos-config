{ inputs, ... }:

{
  imports = [
    ./comms/discord.nix
    ./browser/brave.nix
    ./security
    ./utils/nixvim
    ./dev
    ./virtualisation
    ./other

    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];
}
