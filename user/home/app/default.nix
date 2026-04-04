{ ... }:

{
  imports = [
    ./comms/discord.nix
    ./browser/brave.nix
    ./security/bitwarden.nix
    ./utils/nixvim
    ./dev
    ./virtualisation
    ./other
  ];
}
