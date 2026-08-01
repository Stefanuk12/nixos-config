{ config, pkgs, ... }:
let
  shellAliases = {
    ls = "eza --icons -l -T -L=1";
    rb-home = "sudo nixos-rebuild switch --flake ~/.dotfiles#home --option eval-cache false";
    hm-stefan-home = "home-manager switch --flake ~/.dotfiles#stefan@home --option eval-cache false";
    hows-my-gpu = "sh " + ./../../../../system/home/app/virtualisation/scripts/hows-my-gpu.sh;
    dgpu-enable = "sh " + ./../../../../system/home/app/virtualisation/scripts/dgpu-enable.sh;
    dgpu-disable = "sh " + ./../../../../system/home/app/virtualisation/scripts/dgpu-disable.sh;

    yt = "getmedia";
    ytm = "getmedia -t mp3";
  };
in
{
  programs.zsh = {
    inherit shellAliases;

    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Home Manager defaults this off, which makes every shell exit truncate and rewrite the whole
    # 10k-entry file; a crash mid-rewrite leaves a NUL hole and zsh then reports "corrupt history
    # file" and discards everything past it. Appending keeps the torn-write window to one entry.
    history.append = true;

    # Pins the pre-26.05 default (~/.zshrc). Moving this to $XDG_CONFIG_HOME/zsh relocates
    # .zshrc, and a session holding a stale ZDOTDIR then finds nothing and loses its config.
    dotDir = config.home.homeDirectory;
  };

  home.packages = with pkgs; [
    eza
  ];
}
