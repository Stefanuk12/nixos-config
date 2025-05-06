{ pkgs, ... }:
let
  virtScripts = ./../../../../system/home/app/virtualisation/scripts;
  shellAliases = {
    ls = "eza --icons -l -T -L=1";
    rb-home = "sudo nixos-rebuild switch --flake ~/.dotfiles#home --option eval-cache false";
    hm-stefan-home = "home-manager switch --flake ~/.dotfiles#stefan@home --option eval-cache false";
    hows-my-gpu = "sh " + ./../../../../system/home/app/virtualisation/scripts/hows-my-gpu.sh;
    dgpu-enable = "sh " + ./../../../../system/home/app/virtualisation/scripts/dgpu-enable.sh;
    dgpu-disable = "sh " + ./../../../../system/home/app/virtualisation/scripts/dgpu-disable.sh;
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
