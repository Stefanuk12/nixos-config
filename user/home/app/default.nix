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

  # The nix-flatpak HM module's `enable` default reads `osConfig.services.flatpak.enable`,
  # which is unavailable in standalone home-manager (no osConfig passthrough), so it
  # silently falls back to false. Force-enable it here.
  services.flatpak.enable = true;
}
