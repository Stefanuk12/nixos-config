{ ... }:

{
  imports = [
    ./dev/vscode.nix
    ./comms/discord.nix
    ./browser/brave.nix
    ./security/bitwarden.nix
    ./utils/nixvim
    ./virtualisation
  ];
}