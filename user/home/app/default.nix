{ inputs, ... }:

{
  imports = [
    ./comms/discord.nix
    ./comms/aerc.nix
    ./comms/thunderbird.nix
    ./browser/helium.nix
    ./security
    ./utils/nixvim
    ./dev
    ./virtualisation
    ./other
    ./gaming

    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  # nix-flatpak's `enable` default reads osConfig, absent in standalone home-manager.
  services.flatpak.enable = true;
}
