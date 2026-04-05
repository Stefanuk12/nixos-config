{ ... }:

{
  imports = [
    ./comms/discord.nix
    ./browser/brave.nix
    ./security
    ./utils/nixvim
    ./dev
    ./virtualisation
    ./other
  ];
}
