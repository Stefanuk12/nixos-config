{ ... }:

{
  imports = [
    ./vscode
    ./direnv.nix
    ./github.nix
    ./aws.nix
    ./mise.nix
    ./termius.nix
    ./claude_code.nix
    ./claude_desktop.nix
    ./nixfmt.nix
    ./latex.nix
  ];
}
