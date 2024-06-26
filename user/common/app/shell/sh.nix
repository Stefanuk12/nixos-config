{ pkgs, ... }:
let
  shellAliases = {
    ls = "eza --icons -l -T -L=1";
    rb-home = "sudo nixos-rebuild switch --flake ~/Documents/nixos-config#home --option eval-cache false";
    hm-stefan-home = "home-manager switch --flake ~/Documents/nixos-config#stefan@home --option eval-cache false";
  };
in {
  programs.zsh = {
    inherit shellAliases;

    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initExtra = ''

    '';
  };

  programs.bash = {
    inherit shellAliases;

    enable = true;
    enableCompletion = true;
  };

  home.packages = with pkgs; [
    eza
  ];
}
