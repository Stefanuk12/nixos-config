{ ... }:

{
  imports = [
    ./dev/vscode
    ./comms/discord.nix
    ./browser/brave.nix
    ./security/bitwarden.nix
    ./utils/nixvim
    ./virtualisation
    ./other
  ];
}
