{ inputs, ... }:

{
  imports = [
    ./comms/discord.nix
    ./browser/helium.nix
    ./security
    ./utils/nixvim
    ./dev
    ./virtualisation
    ./other
    ./gaming

    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  # nix-flatpak's `enable` default reads osConfig (absent in standalone home-manager) so it falls back to false; force-enable it here.
  services.flatpak.enable = true;
}
