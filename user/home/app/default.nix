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
    ./gaming

    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];
}
