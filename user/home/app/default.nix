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

  # nix-flatpak's `enable` default reads osConfig, which is absent in standalone
  # home-manager, so it falls back to false. Force-enable it here.
  services.flatpak.enable = true;
}
